defmodule Nintenlixir.RegistersTest do
  use ExUnit.Case, async: true
  use Bitwise

  alias Nintenlixir.Registers
  alias Nintenlixir.ProcessorStatus

  @initial_registers_state %{
    accumulator: 0,
    x: 0,
    y: 0,
    processor_status: ProcessorStatus.InterruptDisable.value() ||| ProcessorStatus.Unused.value(),
    stack_pointer: 0xFD,
    program_counter: 0xFFFC
  }

  @processor :processor

  setup do
    start_supervised({Registers, @processor})
    :ok
  end

  test "Registers.get_registers/1 should return the registers" do
    assert @initial_registers_state == Registers.get_registers(@processor)
  end

  test "Registers.set_registers/2 should update the registers" do
    registers = Registers.get_registers(@processor)
    assert :ok = Registers.set_registers(@processor, %{registers | program_counter: 0xFFFF})

    assert %{@initial_registers_state | program_counter: 0xFFFF} ==
             Registers.get_registers(@processor)
  end

  test "Registers.reset/1 should reset the registers" do
    assert :ok = Registers.reset(@processor)
    assert @initial_registers_state == Registers.get_registers(@processor)
  end
end
