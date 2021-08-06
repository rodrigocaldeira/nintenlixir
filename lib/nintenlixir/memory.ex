defmodule Nintenlixir.Memory do
  use GenServer

  @memory_size 65_536

  # API

  def start_link(processor) do
    GenServer.start(__MODULE__, reset_memory(), name: processor)
  end

  def reset(processor) do
    GenServer.cast(processor, :reset)
  end

  def read(processor, address) do
    GenServer.call(processor, {:read, address})
  end

  def write(processor, address, value) do
    GenServer.cast(processor, {:write, {address, value}})
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

  @impl GenServer
  def handle_cast(:reset, _) do
    {:noreply, reset_memory()}
  end

  def handle_cast({:write, {address, _}}, state)
      when address >= @memory_size or
             address < 0x00,
      do: {:noreply, state}

  def handle_cast({:write, {address, value}}, %{can_write: true, memory: memory} = state) do
    new_memory = List.replace_at(memory, address, value)
    {:noreply, %{state | memory: new_memory}}
  end

  # Private helpers

  defp reset_memory,
    do: %{
      memory: List.duplicate(0xFF, @memory_size),
      can_read: true,
      can_write: true
    }
end
