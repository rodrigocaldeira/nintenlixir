defmodule Nintenlixir.PPU.NameTableMapper do
  use GenServer
  use Bitwise

  defstruct name: "NameTableMapper"

  alias Nintenlixir.Memory.Mapper
  alias __MODULE__

  # Mapper

  defimpl Mapper, for: NameTableMapper do
    def write(_mapper, address, data, _memory) do
      NameTableMapper.write(address, data)
    end

    def read(_mapper, address, _memory) do
      NameTableMapper.read(address)
    end

    def build_mappings(mapper, :ppu) do
      {
        Enum.map(0x2000..0x2FFF, fn address -> {address, mapper} end)
        |> Map.new(),
        Enum.map(0x2000..0x2FFF, fn address -> {address, mapper} end)
        |> Map.new()
      }
    end
  end

  # API

  def start_link(_) do
    GenServer.start(__MODULE__, new_name_table(), name: __MODULE__)
  end

  def get_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  def set_tables(tables) do
    GenServer.call(__MODULE__, {:set_tables, tables})
  end

  def reset() do
    GenServer.call(__MODULE__, :reset)
  end

  def write(address, data) do
    GenServer.call(__MODULE__, {:write, address, data})
  end

  def read(address) do
    GenServer.call(__MODULE__, {:read, address})
  end

  # Server

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_state, _, state), do: {:reply, state, state}

  def handle_call({:set_tables, tables}, _, state) do
    {:reply, :ok, %{state | tables: tables}}
  end

  def handle_call(:reset, _, _) do
    {:reply, :ok, new_name_table()}
  end

  def handle_call({:write, address, data}, _, %{tables: tables, memory: memory} = state) do
    table = address >>> 10 &&& 0x0003
    index = address &&& 0x03FF
    i = Enum.at(tables, table)
    indexed_memory = Map.get(memory, i) |> List.replace_at(index, data)
    memory = Map.replace(memory, i, indexed_memory)
    {:reply, :ok, %{state | memory: memory}}
  end

  def handle_call({:read, address}, _, %{tables: tables, memory: memory} = state) do
    table = address >>> 10 &&& 0x0003
    index = address &&& 0x03FF
    i = Enum.at(tables, table)
    data = Map.get(memory, i) |> Enum.at(index)
    {:reply, data, state}
  end

  # Helpers

  defp new_name_table do
    memory_0 = List.duplicate(0xFF, 0x0400)
    memory_1 = List.duplicate(0xFF, 0x0400)

    memory = %{
      0 => memory_0,
      1 => memory_1
    }

    %{
      tables: [0, 0, 1, 1],
      memory: memory
    }
  end
end
