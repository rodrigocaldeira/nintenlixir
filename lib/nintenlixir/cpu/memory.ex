defmodule Nintenlixir.CPU.Memory do
  use GenServer
  use Bitwise

  @memory_size 65_536

  # API

  def start_link(_) do
    GenServer.start(__MODULE__, reset_memory(), name: __MODULE__)
  end

  def reset() do
    GenServer.call(__MODULE__, :reset)
  end

  def read(address) do
    GenServer.call(__MODULE__, {:read, address})
  end

  def write(address, value) do
    GenServer.call(__MODULE__, {:write, {address, value}})
  end

  def same_page?(address1, address2) do
    bxor(address1, address2) >>> 8 == 0
  end

  # Server

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:read, address}, _, state)
      when address >= @memory_size or
             address < 0x00 do
    {:reply, {:error, :outbound_memory_access}, state}
  end

  def handle_call({:read, address}, _, %{can_read: true, memory: memory} = state) do
    {:reply, {:ok, Enum.at(memory, address)}, state}
  end

  def handle_call({:read, _}, _, %{can_read: false} = state) do
    {:reply, {:error, :cannot_read}, state}
  end

  def handle_call(:reset, _, _) do
    {:reply, :ok, reset_memory()}
  end

  def handle_call({:write, {address, _}}, _, state)
      when address >= @memory_size or
             address < 0x00,
      do: {:reply, :ok, state}

  def handle_call({:write, {address, value}}, _, %{can_write: true, memory: memory} = state) do
    new_memory = List.replace_at(memory, address, value)
    {:reply, :ok, %{state | memory: new_memory}}
  end

  # Private helpers

  defp reset_memory,
    do: %{
      memory: List.duplicate(0xFF, @memory_size),
      can_read: true,
      can_write: true
    }
end
