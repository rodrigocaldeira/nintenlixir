defmodule Nintenlixir.Memory do
  use GenServer
  use Bitwise

  @memory_size 65_536

  # API

  alias Nintenlixir.Memory.Mapper

  def start_link(processor) do
    GenServer.start(__MODULE__, reset_memory(), name: processor)
  end

  def reset(processor) do
    GenServer.call(processor, :reset)
  end

  def read(processor, address) do
    GenServer.call(processor, {:read, address})
  end

  def write(processor, address, value) do
    GenServer.call(processor, {:write, {address, value}})
  end

  def same_page?(address1, address2) do
    bxor(address1, address2) >>> 8 == 0
  end

  def set_mirrors(processor, %{} = mirrors) do
    GenServer.call(processor, {:set_mirrors, mirrors})
  end

  def add_mapper(processor, mapper, reference) do
    mappings = Mapper.build_mappings(mapper, reference)
    :ok = GenServer.call(processor, {:set_read_mappers, mappings})
    GenServer.call(processor, {:set_write_mappers, mappings})
  end

  def disable_reads(processor) do
    GenServer.call(processor, :disable_reads)
  end

  def enable_reads(processor) do
    GenServer.call(processor, :enable_reads)
  end

  def disable_writes(processor) do
    GenServer.call(processor, :disable_writes)
  end

  def enable_writes(processor) do
    GenServer.call(processor, :enable_writes)
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

  def handle_call({:write, {_, _}}, _, %{can_write: false} = state) do
    {:reply, {:error, :cannot_write}, state}
  end

  def handle_call({:set_mirrors, mirrors}, _, state) do
    {:reply, :ok, %{state | mirrors: mirrors}}
  end

  def handle_call({:set_read_mappers, mappers}, _, %{read_mappers: read_mappers} = state) do
    {:reply, :ok, %{state | read_mappers: Map.merge(read_mappers, mappers)}}
  end

  def handle_call({:set_write_mappers, mappers}, _, %{write_mappers: write_mappers} = state) do
    {:reply, :ok, %{state | write_mappers: Map.merge(write_mappers, mappers)}}
  end

  def handle_call(:disable_reads, _, state) do
    {:reply, :ok, %{state | can_read: false}}
  end

  def handle_call(:enable_reads, _, state) do
    {:reply, :ok, %{state | can_read: true}}
  end

  def handle_call(:disable_writes, _, state) do
    {:reply, :ok, %{state | can_write: false}}
  end

  def handle_call(:enable_writes, _, state) do
    {:reply, :ok, %{state | can_write: true}}
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
        retrieve_mirrored_address(mapped_address, mirrors)
    end
  end
end
