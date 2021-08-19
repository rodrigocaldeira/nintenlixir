defmodule Nintenlixir.Memory do
  use GenServer
  use Bitwise

  @memory_size 65_536

  # API

  alias Nintenlixir.Memory.Mapper

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

  def set_mirrors(%{} = mirrors) do
    GenServer.call(__MODULE__, {:set_mirrors, mirrors})
  end

  def set_read_mappers(%{} = mappers) do
    GenServer.call(__MODULE__, {:set_read_mappers, mappers})
  end

  def set_write_mappers(%{} = mappers) do
    GenServer.call(__MODULE__, {:set_write_mappers, mappers})
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

  def handle_call(
        {:read, address},
        _,
        %{
          can_read: true,
          memory: memory,
          mirrors: mirrors,
          read_mappers: read_mappers
        } = state
      ) do
    address = retrieve_mirrored_address(address, mirrors)

    data =
      Map.get(read_mappers, address)
      |> case do
        nil ->
          Enum.at(memory, address)

        mapper ->
          Mapper.read(mapper, address, memory)
      end

    {:reply, {:ok, data}, state}
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

  def handle_call(
        {:write, {address, data}},
        _,
        %{
          can_write: true,
          memory: memory,
          mirrors: mirrors,
          write_mappers: write_mappers
        } = state
      ) do
    address = retrieve_mirrored_address(address, mirrors)

    new_memory =
      Map.get(write_mappers, address)
      |> case do
        nil ->
          List.replace_at(memory, address, data)

        mapper ->
          Mapper.write(mapper, address, data, memory)
      end

    {:reply, :ok, %{state | memory: new_memory}}
  end

  def handle_call({:set_mirrors, mirrors}, _, state) do
    {:reply, :ok, %{state | mirrors: mirrors}}
  end

  def handle_call({:set_read_mappers, mappers}, _, state) do
    {:reply, :ok, %{state | read_mappers: mappers}}
  end

  def handle_call({:set_write_mappers, mappers}, _, state) do
    {:reply, :ok, %{state | write_mappers: mappers}}
  end

  # Private helpers

  defp reset_memory,
    do: %{
      memory: List.duplicate(0xFF, @memory_size),
      mirrors: %{},
      read_mappers: %{},
      write_mappers: %{},
      can_read: true,
      can_write: true
    }

  defp retrieve_mirrored_address(address, mirrors) do
    Map.get(mirrors, address)
    |> case do
      nil ->
        address

      mapped_address ->
        mapped_address
    end
  end
end
