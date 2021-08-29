defmodule Nintenlixir.PPU.NameTableMapperTest do
  use ExUnit.Case

  alias Nintenlixir.PPU.NameTableMapper
  alias Nintenlixir.Memory.Mapper

  setup do
    start_supervised(NameTableMapper)
    :ok
  end

  describe "GenServer" do
    test "NameTableMapper.get_state/0" do
      assert initial_state() == NameTableMapper.get_state()
    end

    test "NameTableMapper.reset/0" do
      assert :ok = NameTableMapper.reset()
      assert initial_state() == NameTableMapper.get_state()
    end

    test "NameTableMapper.set_tables/1" do
      assert :ok = NameTableMapper.set_tables([1, 0, 1, 0])
      assert %{tables: [1, 0, 1, 0]} = NameTableMapper.get_state()
    end
  end

  describe "Mapper" do
    setup do
      mapper = %NameTableMapper{}

      [mapper: mapper]
    end

    test "NameTableMapper.build_mappings/2", %{mapper: mapper} do
      mappings = Enum.map(0x2000..0x2FFF, fn address -> {address, mapper} end) |> Map.new()
      assert mappings == Mapper.build_mappings(mapper, :ppu)
    end

    test "NameTableMapper.write/4", %{mapper: mapper} do
      assert :ok = Mapper.write(mapper, 0x2000, 0x0E, nil)
      %{memory: %{0 => memory}} = NameTableMapper.get_state()
      assert 0x0E = Enum.at(memory, 0)

      assert :ok = Mapper.write(mapper, 0x2FFF, 0x0E, nil)
      %{memory: %{1 => memory}} = NameTableMapper.get_state()
      assert 0x0E = Enum.at(memory, 0x3FF)
    end

    test "NameTableMapper.read/3", %{mapper: mapper} do
      assert :ok = Mapper.write(mapper, 0x2000, 0x0E, nil)
      assert {:ok, 0x0E} = Mapper.read(mapper, 0x2000, nil)
    end
  end

  defp initial_state do
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
