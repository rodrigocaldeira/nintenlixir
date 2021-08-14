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

  # Helpers
  def get_registers, do: Registers.get_registers(MOS6502.registers_server_name())

  def set_registers(registers),
    do: Registers.set_registers(MOS6502.registers_server_name(), registers)

  def read_memory(address), do: Memory.read(MOS6502.memory_server_name(), address)
  def write_memory(address, value), do: Memory.write(MOS6502.memory_server_name(), address, value)
end
