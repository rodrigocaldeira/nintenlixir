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
    %{stack_pointer: sp} = Registers.get_registers(CPU.registers_server_name())

    assert :ok = CPU.push(0xCA)

    %{stack_pointer: new_sp} = Registers.get_registers(CPU.registers_server_name())

    assert new_sp == sp - 1

    assert {:ok, 0xCA} = Memory.read(CPU.memory_server_name(), 0x0100 ||| sp)
  end

  test "CPU.push16/1" do
    %{stack_pointer: sp} = Registers.get_registers(CPU.registers_server_name())

    assert :ok = CPU.push16(0xCAFE)

    %{stack_pointer: new_sp} = Registers.get_registers(CPU.registers_server_name())

    assert new_sp == sp - 2

    assert {:ok, 0xCA} = Memory.read(CPU.memory_server_name(), 0x0100 ||| sp)

    assert {:ok, 0xFE} = Memory.read(CPU.memory_server_name(), 0x0100 ||| sp - 1)
  end

  test "CPU.pop/0" do
    %{stack_pointer: sp} = Registers.get_registers(CPU.registers_server_name())

    Memory.write(CPU.memory_server_name(), 0x0100 ||| sp + 1, 0xCA)

    assert {:ok, 0xCA} = CPU.pop()

    %{stack_pointer: new_sp} = Registers.get_registers(CPU.registers_server_name())

    assert new_sp == sp + 1
  end

  test "CPU.pop16/0" do
    %{stack_pointer: sp} = Registers.get_registers(CPU.registers_server_name())

    Memory.write(CPU.memory_server_name(), 0x0100 ||| sp + 2, 0xCA)

    Memory.write(CPU.memory_server_name(), 0x0100 ||| sp + 1, 0xFE)

    assert {:ok, 0xCAFE} = CPU.pop16()

    %{stack_pointer: new_sp} = Registers.get_registers(CPU.registers_server_name())

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
    %{processor_status: p} = registers = Registers.get_registers(CPU.registers_server_name())

    assert :ok =
             Registers.set_registers(CPU.registers_server_name(), %{
               registers
               | processor_status: p &&& ~~~ProcessorStatus.InterruptDisable.value()
             })

    %{
      program_counter: pc,
      processor_status: p,
      stack_pointer: sp
    } = Registers.get_registers(CPU.registers_server_name())

    {:ok, new_pc_low} = Memory.read(CPU.memory_server_name(), 0xFFFE)
    {:ok, new_pc_high} = Memory.read(CPU.memory_server_name(), 0xFFFF)

    assert :ok = CPU.irq()
    assert %{irq: true} = CPU.get_state()
    assert {:ok, 7} = CPU.interrupt()
    assert %{irq: false} = CPU.get_state()

    %{
      program_counter: new_pc,
      processor_status: new_p,
      stack_pointer: new_sp
    } = Registers.get_registers(CPU.registers_server_name())

    {:ok, previous_p} = Memory.read(CPU.memory_server_name(), 0x0100 ||| sp - 2)
    {:ok, previous_pc_low} = Memory.read(CPU.memory_server_name(), 0x0100 ||| sp - 1)
    {:ok, previous_pc_high} = Memory.read(CPU.memory_server_name(), 0x0100 ||| sp)

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
    } = Registers.get_registers(CPU.registers_server_name())

    {:ok, new_pc_low} = Memory.read(CPU.memory_server_name(), 0xFFFA)
    {:ok, new_pc_high} = Memory.read(CPU.memory_server_name(), 0xFFFB)

    assert :ok = CPU.nmi()
    assert %{nmi: true} = CPU.get_state()
    assert {:ok, 7} = CPU.interrupt()
    assert %{nmi: false} = CPU.get_state()

    %{
      program_counter: new_pc,
      processor_status: new_p,
      stack_pointer: new_sp
    } = Registers.get_registers(CPU.registers_server_name())

    {:ok, previous_p} = Memory.read(CPU.memory_server_name(), 0x0100 ||| sp - 2)
    {:ok, previous_pc_low} = Memory.read(CPU.memory_server_name(), 0x0100 ||| sp - 1)
    {:ok, previous_pc_high} = Memory.read(CPU.memory_server_name(), 0x0100 ||| sp)

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
    assert %{program_counter: 0xFFFF} = Registers.get_registers(CPU.registers_server_name())
  end
end
