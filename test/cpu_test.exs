defmodule Nintenlixir.CPUTest do
  use ExUnit.Case, async: true
  use Bitwise

  alias Nintenlixir.CPU
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
    start_supervised(CPU)
    start_supervised({Memory, CPU.memory_server_name()})
    start_supervised({Registers, CPU.registers_server_name()})
    :ok
  end

  test "CPU.get_state/0" do
    assert @initial_state == CPU.get_state()
  end

  test "CPU.reset/0" do
    assert :ok = CPU.reset()
  end

  test "CPU.push/1" do
    %{stack_pointer: sp} = get_registers()

    assert :ok = CPU.push(0xCA)

    %{stack_pointer: new_sp} = get_registers()

    assert new_sp == sp - 1

    assert {:ok, 0xCA} = read_memory(0x0100 ||| sp)
  end

  test "CPU.push16/1" do
    %{stack_pointer: sp} = get_registers()

    assert :ok = CPU.push16(0xCAFE)

    %{stack_pointer: new_sp} = get_registers()

    assert new_sp == sp - 2

    assert {:ok, 0xCA} = read_memory(0x0100 ||| sp)

    assert {:ok, 0xFE} = read_memory(0x0100 ||| sp - 1)
  end

  test "CPU.pop/0" do
    %{stack_pointer: sp} = get_registers()

    write_memory(0x0100 ||| sp + 1, 0xCA)

    assert {:ok, 0xCA} = CPU.pop()

    %{stack_pointer: new_sp} = get_registers()

    assert new_sp == sp + 1
  end

  test "CPU.pop16/0" do
    %{stack_pointer: sp} = get_registers()

    write_memory(0x0100 ||| sp + 2, 0xCA)

    write_memory(0x0100 ||| sp + 1, 0xFE)

    assert {:ok, 0xCAFE} = CPU.pop16()

    %{stack_pointer: new_sp} = get_registers()

    assert new_sp == sp + 2
  end

  test "CPU.irq/0" do
    assert :ok = CPU.irq()
    assert %{@initial_state | irq: true} == CPU.get_state()
  end

  test "CPU.nmi/0" do
    assert :ok = CPU.nmi()
    assert %{@initial_state | nmi: true} == CPU.get_state()
  end

  test "CPU.rst/0" do
    assert :ok = CPU.rst()
    assert %{@initial_state | rst: true} == CPU.get_state()
  end

  test "CPU.interrupt/0 with no interrupts set" do
    assert {:ok, 0} = CPU.interrupt()
  end

  test "CPU.interrupt/0 with irq" do
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

    assert :ok = CPU.irq()
    assert %{irq: true} = CPU.get_state()
    assert {:ok, 7} = CPU.interrupt()
    assert %{irq: false} = CPU.get_state()

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

  test "CPU.interrupt/0 with nmi" do
    %{
      program_counter: pc,
      processor_status: p,
      stack_pointer: sp
    } = get_registers()

    {:ok, new_pc_low} = read_memory(0xFFFA)
    {:ok, new_pc_high} = read_memory(0xFFFB)

    assert :ok = CPU.nmi()
    assert %{nmi: true} = CPU.get_state()
    assert {:ok, 7} = CPU.interrupt()
    assert %{nmi: false} = CPU.get_state()

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

  test "CPU.interrupt/0 with rst" do
    assert :ok = CPU.rst()
    assert %{rst: true} = CPU.get_state()
    assert {:ok, 7} = CPU.interrupt()
    assert %{rst: false} = CPU.get_state()
    assert %{program_counter: 0xFFFF} = get_registers()
  end

  test "CPU.set_Z_flag/1 with 0x00" do
    assert {:ok, 0x00} = CPU.set_Z_flag(0x00)
    assert %{processor_status: 0x26} = get_registers()
  end

  test "CPU.set_Z_flag/1 with other value" do
    assert {:ok, 0xCA} = CPU.set_Z_flag(0xCA)
    assert %{processor_status: 0x24} = get_registers()
  end

  test "CPU.set_N_flag/1" do
    assert {:ok, 0xCA} = CPU.set_N_flag(0xCA)
    assert %{processor_status: 0xA4} = get_registers()
  end

  test "CPU.set_C_flag_addition/1" do
    assert {:ok, 0xCA} = CPU.set_C_flag_addition(0xCA)
    assert %{processor_status: 0x24} = get_registers()
  end

  test "CPU.set_V_flag_addition/3" do
    assert {:ok, 0x80} = CPU.set_V_flag_addition(0x78, 0x08, 0x80)
    assert %{processor_status: 0x64} = get_registers()
  end

  test "CPU.immediate_address/0" do
    assert {:ok, 0xFFFC} = CPU.immediate_address()
    assert %{program_counter: 0xFFFD} = get_registers()
  end

  test "CPU.zero_page_address/0" do
    {:ok, 0xFF} = CPU.zero_page_address()
    assert %{program_counter: 0xFFFD} = get_registers()
  end

  test "CPU.relative_address/0 when value in memory is bigger than 0x7F" do
    %{program_counter: pc} = get_registers()
    write_memory(pc, 0x80)
    assert {:ok, 0xFF7D} = CPU.relative_address()
    assert %{program_counter: 0xFFFD} = get_registers()
  end

  test "CPU.relative_address/0 when value in memory is lesser or equal to 0x7F" do
    %{program_counter: pc} = get_registers()
    write_memory(pc, 0x7F)
    assert {:ok, 0x7C} = CPU.relative_address()
    assert %{program_counter: 0xFFFD} = get_registers()
  end

  test "CPU.absolute_address/0" do
    %{program_counter: pc} = get_registers()
    write_memory(pc, 0xFE)
    write_memory(pc + 1, 0xCA)
    assert {:ok, 0xCAFE} = CPU.absolute_address()
    assert %{program_counter: 0xFFFE} = get_registers()
  end

  # Helpers
  def get_registers, do: Registers.get_registers(CPU.registers_server_name())

  def set_registers(registers),
    do: Registers.set_registers(CPU.registers_server_name(), registers)

  def read_memory(address), do: Memory.read(CPU.memory_server_name(), address)
  def write_memory(address, value), do: Memory.write(CPU.memory_server_name(), address, value)
end
