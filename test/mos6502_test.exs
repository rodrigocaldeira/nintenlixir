defmodule Nintenlixir.MOS6502Test do
  use ExUnit.Case, async: true
  use Bitwise

  alias Nintenlixir.MOS6502
  alias Nintenlixir.Memory
  alias Nintenlixir.Registers
  alias Nintenlixir.ProcessorStatus

  @initial_state %{
    decimal_mode: true,
    break_error: false,
    nmi: false,
    irq: false,
    rst: false
  }

  setup do
    start_supervised(MOS6502)
    start_supervised({Memory, MOS6502.memory_server_name()})
    start_supervised({Registers, MOS6502.registers_server_name()})
    :ok
  end

  test "MOS6502.get_state/0" do
    assert @initial_state == MOS6502.get_state()
  end

  test "MOS6502.reset/0" do
    assert :ok = MOS6502.reset()
  end

  test "MOS6502.push/1" do
    %{stack_pointer: sp} = get_registers()

    assert :ok = MOS6502.push(0xCA)

    %{stack_pointer: new_sp} = get_registers()

    assert new_sp == sp - 1

    assert {:ok, 0xCA} = read_memory(0x0100 ||| sp)
  end

  test "MOS6502.push16/1" do
    %{stack_pointer: sp} = get_registers()

    assert :ok = MOS6502.push16(0xCAFE)

    %{stack_pointer: new_sp} = get_registers()

    assert new_sp == sp - 2

    assert {:ok, 0xCA} = read_memory(0x0100 ||| sp)

    assert {:ok, 0xFE} = read_memory(0x0100 ||| sp - 1)
  end

  test "MOS6502.pop/0" do
    %{stack_pointer: sp} = get_registers()

    write_memory(0x0100 ||| sp + 1, 0xCA)

    assert {:ok, 0xCA} = MOS6502.pop()

    %{stack_pointer: new_sp} = get_registers()

    assert new_sp == sp + 1
  end

  test "MOS6502.pop16/0" do
    %{stack_pointer: sp} = get_registers()

    write_memory(0x0100 ||| sp + 2, 0xCA)

    write_memory(0x0100 ||| sp + 1, 0xFE)

    assert {:ok, 0xCAFE} = MOS6502.pop16()

    %{stack_pointer: new_sp} = get_registers()

    assert new_sp == sp + 2
  end

  test "MOS6502.irq/0" do
    assert :ok = MOS6502.irq()
    assert %{@initial_state | irq: true} == MOS6502.get_state()
  end

  test "MOS6502.nmi/0" do
    assert :ok = MOS6502.nmi()
    assert %{@initial_state | nmi: true} == MOS6502.get_state()
  end

  test "MOS6502.rst/0" do
    assert :ok = MOS6502.rst()
    assert %{@initial_state | rst: true} == MOS6502.get_state()
  end

  test "MOS6502.interrupt/0 with no interrupts set" do
    assert {:ok, 0} = MOS6502.interrupt()
  end

  test "MOS6502.interrupt/0 with irq" do
    %{processor_status: p} = registers = get_registers()

    assert :ok =
             set_registers(%{
               registers
               | processor_status: p &&& ~~~ProcessorStatus.InterruptDisable.value()
             })

    %{
      program_counter: pc,
      processor_status: p,
      stack_pointer: sp
    } = get_registers()

    {:ok, new_pc_low} = read_memory(0xFFFE)
    {:ok, new_pc_high} = read_memory(0xFFFF)

    assert :ok = MOS6502.irq()
    assert %{irq: true} = MOS6502.get_state()
    assert {:ok, 7} = MOS6502.interrupt()
    assert %{irq: false} = MOS6502.get_state()

    %{
      program_counter: new_pc,
      processor_status: new_p,
      stack_pointer: new_sp
    } = get_registers()

    {:ok, previous_p} = read_memory(0x0100 ||| sp - 2)
    {:ok, previous_pc_low} = read_memory(0x0100 ||| sp - 1)
    {:ok, previous_pc_high} = read_memory(0x0100 ||| sp)

    assert ((previous_p ||| ProcessorStatus.Unused.value()) &&&
              ~~~ProcessorStatus.BreakCommand.value()) == p

    assert (previous_pc_high <<< 8 ||| previous_pc_low) == pc
    assert (new_pc_high <<< 8 ||| new_pc_low) == new_pc
    assert (p ||| ProcessorStatus.InterruptDisable.value()) == new_p
    assert sp - 3 == new_sp
  end

  test "MOS6502.interrupt/0 with nmi" do
    %{
      program_counter: pc,
      processor_status: p,
      stack_pointer: sp
    } = get_registers()

    {:ok, new_pc_low} = read_memory(0xFFFA)
    {:ok, new_pc_high} = read_memory(0xFFFB)

    assert :ok = MOS6502.nmi()
    assert %{nmi: true} = MOS6502.get_state()
    assert {:ok, 7} = MOS6502.interrupt()
    assert %{nmi: false} = MOS6502.get_state()

    %{
      program_counter: new_pc,
      processor_status: new_p,
      stack_pointer: new_sp
    } = get_registers()

    {:ok, previous_p} = read_memory(0x0100 ||| sp - 2)
    {:ok, previous_pc_low} = read_memory(0x0100 ||| sp - 1)
    {:ok, previous_pc_high} = read_memory(0x0100 ||| sp)

    assert ((previous_p ||| ProcessorStatus.Unused.value()) &&&
              ~~~ProcessorStatus.BreakCommand.value()) == p

    assert (previous_pc_high <<< 8 ||| previous_pc_low) == pc
    assert (new_pc_high <<< 8 ||| new_pc_low) == new_pc
    assert (p ||| ProcessorStatus.InterruptDisable.value()) == new_p
    assert sp - 3 == new_sp
  end

  test "MOS6502.interrupt/0 with rst" do
    assert :ok = MOS6502.rst()
    assert %{rst: true} = MOS6502.get_state()
    assert {:ok, 7} = MOS6502.interrupt()
    assert %{rst: false} = MOS6502.get_state()
    assert %{program_counter: 0xFFFF} = get_registers()
  end

  test "MOS6502.set_Z_flag/1 with 0x00" do
    assert {:ok, 0x00} = MOS6502.set_Z_flag(0x00)
    assert %{processor_status: 0x26} = get_registers()
  end

  test "MOS6502.set_Z_flag/1 with other value" do
    assert {:ok, 0xCA} = MOS6502.set_Z_flag(0xCA)
    assert %{processor_status: 0x24} = get_registers()
  end

  test "MOS6502.set_N_flag/1" do
    assert {:ok, 0xCA} = MOS6502.set_N_flag(0xCA)
    assert %{processor_status: 0xA4} = get_registers()
  end

  test "MOS6502.set_ZN_flags/1" do
    assert {:ok, 0xCA} = MOS6502.set_ZN_flags(0xCA)
    assert %{processor_status: 0xA4} = get_registers()
  end

  test "MOS6502.set_C_flag_addition/1" do
    assert {:ok, 0xCA} = MOS6502.set_C_flag_addition(0xCA)
    assert %{processor_status: 0x24} = get_registers()
  end

  test "MOS6502.set_V_flag_addition/3" do
    assert {:ok, 0x80} = MOS6502.set_V_flag_addition(0x78, 0x08, 0x80)
    assert %{processor_status: 0x64} = get_registers()
  end

  test "MOS6502.immediate_address/0" do
    assert {:ok, 0xFFFC} = MOS6502.immediate_address()
    assert %{program_counter: 0xFFFD} = get_registers()
  end

  test "MOS6502.zero_page_address/0" do
    {:ok, 0xFF} = MOS6502.zero_page_address()
    assert %{program_counter: 0xFFFD} = get_registers()
  end

  test "MOS6502.zero_page_address/1" do
    %{program_counter: pc} = registers = get_registers()
    set_registers(%{registers | x: 1, y: 2})

    write_memory(pc, 0xCA)
    write_memory(pc + 1, 0xFE)

    assert {:ok, 0xCB} = MOS6502.zero_page_address(:x)
    assert {:ok, 0x0100} = MOS6502.zero_page_address(:y)

    assert %{program_counter: 0xFFFE} = get_registers()
  end

  test "MOS6502.relative_address/0 when value in memory is bigger than 0x7F" do
    %{program_counter: pc} = get_registers()
    write_memory(pc, 0x80)
    assert {:ok, 0xFF7D} = MOS6502.relative_address()
    assert %{program_counter: 0xFFFD} = get_registers()
  end

  test "MOS6502.relative_address/0 when value in memory is lesser or equal to 0x7F" do
    %{program_counter: pc} = get_registers()
    write_memory(pc, 0x7F)
    assert {:ok, 0x7C} = MOS6502.relative_address()
    assert %{program_counter: 0xFFFD} = get_registers()
  end

  test "MOS6502.absolute_address/0" do
    %{program_counter: pc} = get_registers()
    write_memory(pc, 0xFE)
    write_memory(pc + 1, 0xCA)
    assert {:ok, 0xCAFE} = MOS6502.absolute_address()
    assert %{program_counter: 0xFFFE} = get_registers()
  end

  test "MOS6502.absolute_address/1 without page cross" do
    registers = get_registers()
    pc = 0xFFF0
    set_registers(%{registers | program_counter: pc, x: 1, y: 2})
    write_memory(pc, 0xBA)
    write_memory(pc + 1, 0xBA)
    write_memory(pc + 2, 0xBA)
    write_memory(pc + 3, 0xBA)
    assert {:ok, 0xBABB, :same_page} = MOS6502.absolute_address(:x)
    assert {:ok, 0xBABC, :same_page} = MOS6502.absolute_address(:y)
    assert %{program_counter: 0xFFF4} = get_registers()
  end

  test "MOS6502.absolute_address/1 with page cross" do
    registers = get_registers()
    pc = 0xFFF0
    set_registers(%{registers | program_counter: pc, x: 1, y: 2})
    write_memory(pc + 1, 0xBA)
    write_memory(pc + 3, 0xBA)
    assert {:ok, 0xBB00, :page_cross} = MOS6502.absolute_address(:x)
    assert {:ok, 0xBB01, :page_cross} = MOS6502.absolute_address(:y)
    assert %{program_counter: 0xFFF4} = get_registers()
  end

  test "MOS6502.indirect_address/0" do
    %{program_counter: pc} = get_registers()
    write_memory(pc, 0xFE)
    write_memory(pc + 1, 0xCA)

    write_memory(0xCAFE, 0xFE)
    write_memory(0xCAFF, 0xCA)

    assert {:ok, 0xCAFE} = MOS6502.indirect_address()
    assert %{program_counter: 0xFFFE} = get_registers()
  end

  test "MOS6502.indirect_address/1 indexed by register X" do
    %{program_counter: pc} = registers = get_registers()
    set_registers(%{registers | x: 1})
    write_memory(pc + 1, 0xFE)
    write_memory(pc + 2 &&& 0x00FF, 0xCA)

    write_memory(0xCAFE, 0xFE)
    write_memory(0xCAFF, 0xCA)

    assert {:ok, 0xCAFE} = MOS6502.indirect_address(:x)
    assert %{program_counter: 0xFFFD} = get_registers()
  end

  test "MOS6502.indirect_address/1 indexed by register Y without page cross" do
    %{program_counter: pc} = registers = get_registers()
    set_registers(%{registers | y: 1})

    write_memory(pc, 0xFE)
    write_memory(pc + 1 &&& 0x00FF, 0xCA)

    assert {:ok, 0xCAFF, :same_page} = MOS6502.indirect_address(:y)
    assert %{program_counter: 0xFFFD} = get_registers()
  end

  test "MOS6502.indirect_address/1 indexed by register Y with page cross" do
    %{program_counter: pc} = registers = get_registers()
    set_registers(%{registers | y: 1})

    write_memory(pc, 0xFF)
    write_memory(pc + 1 &&& 0x00FF, 0xCA)

    assert {:ok, 0xCB00, :page_cross} = MOS6502.indirect_address(:y)
    assert %{program_counter: 0xFFFD} = get_registers()
  end

  test "MOS6502.load/2" do
    registers = get_registers()
    write_memory(0xCAFE, 0x0E)
    assert {:ok, 0x0E} = MOS6502.load(0xCAFE, :accumulator)
    assert %{accumulator: 0x0E} = get_registers()
    set_registers(registers)
    assert {:ok, 0x0E} = MOS6502.load(0xCAFE, :x)
    assert %{x: 0x0E} = get_registers()
    set_registers(registers)
    assert {:ok, 0x0E} = MOS6502.load(0xCAFE, :y)
    assert %{y: 0x0E} = get_registers()
  end

  test "MOS6502.lda/1" do
    write_memory(0xCAFE, 0x0E)
    assert :ok = MOS6502.lda(0xCAFE)
    assert %{accumulator: 0x0E} = get_registers()
  end

  test "MOS6502.lax/1" do
    write_memory(0xCAFE, 0x0E)
    assert :ok = MOS6502.lax(0xCAFE)
    assert %{accumulator: 0x0E, x: 0x0E} = get_registers()
  end

  test "MOS6502.ldx/1" do
    write_memory(0xCAFE, 0x0E)
    assert :ok = MOS6502.ldx(0xCAFE)
    assert %{x: 0x0E} = get_registers()
  end

  test "MOS6502.ldy/1" do
    write_memory(0xCAFE, 0x0E)
    assert :ok = MOS6502.ldy(0xCAFE)
    assert %{y: 0x0E} = get_registers()
  end

  test "MOS6502.sax/1" do
    registers = get_registers()
    set_registers(%{registers | accumulator: 3, x: 2})
    assert :ok = MOS6502.sax(0xCAFE)
    assert {:ok, 2} = read_memory(0xCAFE)
  end

  test "MOS6502.sta/1" do
    registers = get_registers()
    set_registers(%{registers | accumulator: 3})
    assert :ok = MOS6502.sta(0xCAFE)
    assert {:ok, 3} = read_memory(0xCAFE)
  end

  test "MOS6502.stx/1" do
    registers = get_registers()
    set_registers(%{registers | x: 3})
    assert :ok = MOS6502.stx(0xCAFE)
    assert {:ok, 3} = read_memory(0xCAFE)
  end

  test "MOS6502.sty/1" do
    registers = get_registers()
    set_registers(%{registers | y: 3})
    assert :ok = MOS6502.sty(0xCAFE)
    assert {:ok, 3} = read_memory(0xCAFE)
  end

  test "MOS6502.transfer/2" do
    registers = get_registers()
    set_registers(%{registers | accumulator: 1})
    assert :ok = MOS6502.transfer(:accumulator, :x)
    assert %{x: 1, accumulator: 1} = get_registers()
    set_registers(%{registers | x: 2})
    assert :ok = MOS6502.transfer(:x, :accumulator)
    assert %{x: 2, accumulator: 2} = get_registers()
    set_registers(%{registers | y: 3})
    assert :ok = MOS6502.transfer(:y, :x)
    assert %{x: 3, y: 3} = get_registers()
  end

  test "MOS6502.tax/0" do
    registers = get_registers()
    set_registers(%{registers | accumulator: 1})
    assert :ok = MOS6502.tax()
    assert %{accumulator: 1, x: 1} = get_registers()
  end

  test "MOS6502.tay/0" do
    registers = get_registers()
    set_registers(%{registers | accumulator: 2})
    assert :ok = MOS6502.tay()
    assert %{accumulator: 2, y: 2} = get_registers()
  end

  test "MOS6502.txa/0" do
    registers = get_registers()
    set_registers(%{registers | x: 3})
    assert :ok = MOS6502.txa()
    assert %{accumulator: 3, x: 3} = get_registers()
  end

  test "MOS6502.tya/0" do
    registers = get_registers()
    set_registers(%{registers | y: 4})
    assert :ok = MOS6502.tya()
    assert %{accumulator: 4, y: 4} = get_registers()
  end

  test "MOS6502.tsx/0" do
    registers = get_registers()
    set_registers(%{registers | stack_pointer: 5})
    assert :ok = MOS6502.tsx()
    assert %{stack_pointer: 5, x: 5} = get_registers()
  end

  test "MOS6502.txs/0" do
    %{processor_status: p} = registers = get_registers()
    set_registers(%{registers | x: 6})
    assert :ok = MOS6502.txs()

    assert %{
             stack_pointer: 6,
             x: 6,
             processor_status: ^p
           } = get_registers()
  end

  test "MOS6502.pha/0" do
    %{stack_pointer: sp} = registers = get_registers()
    set_registers(%{registers | accumulator: 0x0A})
    assert :ok = MOS6502.pha()
    assert {:ok, 0x0A} = read_memory(0x0100 ||| sp)
  end

  test "MOS6502.php/0" do
    %{stack_pointer: sp} = get_registers()
    assert :ok = MOS6502.php()
    assert {:ok, 0x34} = read_memory(0x0100 ||| sp)
  end

  test "MOS6502.pla/0" do
    %{stack_pointer: sp} = registers = get_registers()
    write_memory(0x0100 ||| sp, 0x0E)
    set_registers(%{registers | stack_pointer: sp - 1})
    assert :ok = MOS6502.pla()
    assert %{accumulator: 0x0E, stack_pointer: ^sp} = get_registers()
  end

  test "MOS6502.plp/0" do
    %{stack_pointer: sp} = registers = get_registers()
    write_memory(0x0100 ||| sp, 0x34)
    set_registers(%{registers | stack_pointer: sp - 1})
    assert :ok = MOS6502.plp()
    assert %{processor_status: 0x04, stack_pointer: ^sp} = get_registers()
  end

  test "MOS6502.and_op/1" do
    registers = get_registers()
    write_memory(0xCAFE, 0x02)
    set_registers(%{registers | accumulator: 0x03})
    assert :ok = MOS6502.and_op(0xCAFE)
    assert %{accumulator: 0x02} = get_registers()
  end

  test "MOS6502.xor_op/1" do
    registers = get_registers()
    write_memory(0xCAFE, 0x03)
    set_registers(%{registers | accumulator: 0x05})
    assert :ok = MOS6502.xor_op(0xCAFE)
    assert %{accumulator: 0x06} = get_registers()
  end

  test "MOS6502.or_op/1" do
    registers = get_registers()
    write_memory(0xCAFE, 0x03)
    set_registers(%{registers | accumulator: 0x05})
    assert :ok = MOS6502.or_op(0xCAFE)
    assert %{accumulator: 0x07} = get_registers()
  end

  test "MOS6502.bit/1" do
    write_memory(0xCAFE, 0x03)
    assert :ok = MOS6502.bit(0xCAFE)
    assert %{processor_status: 0x24} = get_registers()
  end

  test "MOS6502.disable_decimal_mode" do
    assert :ok = MOS6502.disable_decimal_mode()
    assert %{decimal_mode: false} = MOS6502.get_state()
  end

  test "MOS6502.addition/1 when the chip is not in decimal mode" do
    assert :ok = MOS6502.disable_decimal_mode()
    registers = get_registers()
    set_registers(%{registers | accumulator: 0x02})
    assert :ok = MOS6502.addition(0x03)
    assert %{accumulator: 0x05} = get_registers()
  end

  test "MOS6502.addition/1 when processor_status is not in decimal mode" do
    registers = get_registers()
    set_registers(%{registers | accumulator: 0x02})
    assert :ok = MOS6502.addition(0x03)
    assert %{accumulator: 0x05} = get_registers()
  end

  test "MOS6502.addition/1 when processor_status is in decimal mode" do
    %{processor_status: p} = registers = get_registers()

    set_registers(%{
      registers
      | accumulator: 0x02,
        processor_status: p ||| ProcessorStatus.DecimalMode.value()
    })

    assert :ok = MOS6502.addition(0x03)
    assert %{accumulator: 0x05} = get_registers()
  end

  test "MOS6502.adc/1" do
    registers = get_registers()
    write_memory(0xCAFE, 0x04)
    set_registers(%{registers | accumulator: 0x02})
    assert :ok = MOS6502.adc(0xCAFE)
    assert %{accumulator: 0x06} = get_registers()
  end

  test "MOS6502.sbc/1 when the chip is not in decimal mode" do
    assert :ok = MOS6502.disable_decimal_mode()
    registers = get_registers()
    write_memory(0xCAFE, 0x02)
    set_registers(%{registers | accumulator: 0x01})
    assert :ok = MOS6502.sbc(0xCAFE)
    assert %{accumulator: 0xFE} = get_registers()
  end

  test "MOS6502.sbc/1 when processor_status is in decimal mode" do
    %{processor_status: p} = registers = get_registers()

    set_registers(%{
      registers
      | accumulator: 0x01,
        processor_status: p ||| ProcessorStatus.DecimalMode.value()
    })

    write_memory(0xCAFE, 0x02)
    assert :ok = MOS6502.sbc(0xCAFE)
    assert %{accumulator: 0x98} = get_registers()
  end

  test "MOS6502.compare/2" do
    assert :ok = MOS6502.compare(0xCA, 0xFE)
    assert %{processor_status: 0x25} = get_registers()
  end

  test "MOS6502.cmp/1" do
    write_memory(0xCAFE, 0xCA)
    set_registers(%{get_registers() | accumulator: 0xFE})
    assert :ok = MOS6502.cmp(0xCAFE)
    assert %{processor_status: 0x25} = get_registers()
  end

  test "MOS6502.cpx/1" do
    write_memory(0xCAFE, 0xCA)
    set_registers(%{get_registers() | x: 0xFE})
    assert :ok = MOS6502.cpx(0xCAFE)
    assert %{processor_status: 0x25} = get_registers()
  end

  test "MOS6502.cpy/1" do
    write_memory(0xCAFE, 0xCA)
    set_registers(%{get_registers() | y: 0xFE})
    assert :ok = MOS6502.cpy(0xCAFE)
    assert %{processor_status: 0x25} = get_registers()
  end

  test "MOS6502.inc/1 for memory" do
    write_memory(0xCAFE, 0xCA)
    assert :ok = MOS6502.inc(0xCAFE)
    assert {:ok, 0xCB} = read_memory(0xCAFE)
  end

  test "MOS6502.inc/1 for registers" do
    assert :ok = MOS6502.inc(:x)
    assert :ok = MOS6502.inc(:y)
    assert :ok = MOS6502.inc(:accumulator)
    assert %{accumulator: 1, x: 1, y: 1} = get_registers()
  end

  test "MOS6502.dec/1 for memory" do
    write_memory(0xCAFE, 0xCB)
    assert :ok = MOS6502.dec(0xCAFE)
    assert {:ok, 0xCA} = read_memory(0xCAFE)
  end

  test "MOS6502.dec/1 for registers" do
    set_registers(%{get_registers() | accumulator: 1, x: 1, y: 1})
    assert :ok = MOS6502.dec(:x)
    assert :ok = MOS6502.dec(:y)
    assert :ok = MOS6502.dec(:accumulator)
    assert %{accumulator: 0, x: 0, y: 0} = get_registers()
  end

  # Helpers
  def get_registers, do: Registers.get_registers(MOS6502.registers_server_name())

  def set_registers(registers),
    do: Registers.set_registers(MOS6502.registers_server_name(), registers)

  def read_memory(address), do: Memory.read(MOS6502.memory_server_name(), address)
  def write_memory(address, value), do: Memory.write(MOS6502.memory_server_name(), address, value)
end
