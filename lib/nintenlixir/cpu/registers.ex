defmodule Nintenlixir.CPU.Registers do
  use GenServer
  use Bitwise

  # API

  def start_link(processor) do
    GenServer.start_link(__MODULE__, reset_registers(), name: processor)
  end

  def reset(processor) do
    GenServer.call(processor, :reset)
  end

  def get_registers(processor) do
    GenServer.call(processor, :get_registers)
  end

  def set_registers(processor, registers) do
    GenServer.call(processor, {:set_registers, registers})
  end

  # Server

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:reset, _, _) do
    {:reply, :ok, reset_registers()}
  end

  def handle_call(:get_registers, _, registers) do
    {:reply, registers, registers}
  end

  def handle_call({:set_registers, new_registers}, _, _) do
    {:reply, :ok, new_registers}
  end

  # Private helpers

  defp reset_registers,
    do: %{
      accumulator: 0,
      x: 0,
      y: 0,
      processor_status: 36,
      stack_pointer: 0xFD,
      program_counter: 0xFFFC
    }
end
