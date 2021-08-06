defmodule Nintenlixir.CPU do
  use GenServer

  # API

  def start_link(_) do
    GenServer.start_link(__MODULE__, new_cpu(), name: __MODULE__)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  # Server

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_state, _, state) do
    {:reply, state, state}
  end

  # Private helpers

  defp new_cpu(),
    do: %{
      decimal_mode: true,
      break_error: false,
      nmi: false,
      irq: false,
      rst: false
    }
end
