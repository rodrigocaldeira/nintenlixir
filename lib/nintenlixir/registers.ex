defmodule Nintenlixir.Registers do
  use GenServer
  use Bitwise

  alias Nintenlixir.ProcessorStatus

  # API

  def start_link(processor) do
    GenServer.start_link(__MODULE__, reset_registers(), name: processor)
  end

  def reset(processor) do
    GenServer.cast(processor, :reset)
  end

  def get_registers(processor) do
    GenServer.call(processor, :get_registers)
  end

  # Server

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_cast(:reset, _) do
    {:noreply, reset_registers()}
  end

  @impl GenServer
  def handle_call(:get_registers, _, registers) do
    {:reply, registers, registers}
  end

  # Private helpers

  defp reset_registers,
    do: %{
      accumulator: 0,
      x: 0,
      y: 0,
      processor_status:
        ProcessorStatus.InterruptDisable.value() ||| ProcessorStatus.Unused.value(),
      stack_pointer: 0xFD,
      program_counter: 0xFFFC
    }
end