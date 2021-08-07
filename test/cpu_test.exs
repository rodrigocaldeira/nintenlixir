defmodule Nintenlixir.CPUTest do
  use ExUnit.Case, async: true
  use Bitwise

  alias Nintenlixir.CPU
  alias Nintenlixir.Memory
  alias Nintenlixir.Registers

  setup do
    start_supervised(CPU)
    start_supervised({Memory, CPU.memory_server_name()})
    start_supervised({Registers, CPU.registers_server_name()})
    :ok
  end

  test "CPU.get_state/0 should return a brand new CPU state in it's creation" do
    assert %{
             decimal_mode: true,
             break_error: false,
             nmi: false,
             irq: false,
             rst: false
           } == CPU.get_state()
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
end
