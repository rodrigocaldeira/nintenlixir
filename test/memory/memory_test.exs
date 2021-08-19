defmodule Nintenlixir.MemoryTest do
  use ExUnit.Case

  alias Nintenlixir.Memory
  alias Nintenlixir.Memory.DummyMapper

  setup do
    start_supervised(Memory)
    :ok
  end

  test "Memory.read/2 in fresh memory should return 0xff" do
    assert {:ok, 0xFF} == Memory.read(0x05)
  end

  test "Memory.read/2 should return error on outbound memory access" do
    assert {:error, :outbound_memory_access} == Memory.read(-1)
    assert {:error, :outbound_memory_access} == Memory.read(70_000)
  end

  test "Memory.write/3 should update the memory" do
    assert :ok = Memory.write(0x65, 0x90)
    assert {:ok, 0x90} == Memory.read(0x65)
  end

  test "Memory.write/3 should not update the memory on outbound memory access" do
    assert :ok = Memory.write(-1, 0x90)
    assert {:ok, 0xFF} == Memory.read(0xFFFF)
  end

  test "Memory.reset/1 should reset the memory" do
    assert :ok = Memory.write(0x65, 0x90)
    assert :ok = Memory.write(0x66, 0x91)
    assert :ok = Memory.write(0x67, 0x92)
    assert :ok = Memory.write(0x68, 0x93)
    assert :ok = Memory.write(0x69, 0x94)
    assert :ok = Memory.write(0x6AFF, 0x95)

    assert :ok = Memory.reset()

    assert {:ok, 0xFF} == Memory.read(0x65)
    assert {:ok, 0xFF} == Memory.read(0x66)
    assert {:ok, 0xFF} == Memory.read(0x67)
    assert {:ok, 0xFF} == Memory.read(0x68)
    assert {:ok, 0xFF} == Memory.read(0x69)
    assert {:ok, 0xFF} == Memory.read(0x6AFF)
  end

  test "Memory.same_page?/2" do
    assert Memory.same_page?(0x0100, 0x0140)
    assert Memory.same_page?(0x0010, 0x00FA)
    assert Memory.same_page?(0x02CA, 0x02FE)
    refute Memory.same_page?(0x0001, 0x0100)
    refute Memory.same_page?(0x0100, 0x02FA)
    refute Memory.same_page?(0x02CA, 0x03FE)
  end

  test "Memory.set_mirrors/1" do
    assert {:ok, 0xFF} = Memory.read(0xEFAC)
    assert :ok = Memory.write(0xCAFE, 0x0E)
    assert {:ok, 0x0E} = Memory.read(0xCAFE)

    mirrors = %{
      0xCAFE => 0xEFAC
    }

    assert :ok = Memory.set_mirrors(mirrors)

    assert :ok = Memory.write(0xCAFE, 0xFA)
    assert {:ok, 0xFA} = Memory.read(0xEFAC)

    assert :ok = Memory.write(0xEFAC, 0xAE)
    assert {:ok, 0xAE} = Memory.read(0xCAFE)
  end

  test "Dummy mapper" do
    dummy_mapper = %DummyMapper{}

    read_mappers = %{
      0xCAFE => dummy_mapper
    }

    write_mappers = %{
      0xCAFE => dummy_mapper
    }

    assert :ok = Memory.set_read_mappers(read_mappers)
    assert :ok = Memory.set_write_mappers(write_mappers)

    assert {:ok, "DUMMY MAPPER"} = Memory.read(0xCAFE)
    assert :ok = Memory.write(0xCAFE, 0x1234)
    assert {:ok, 0xCAFE} = Memory.read(0x1234)

    mappers = Enum.map(0x0200..0x3FFF, fn address -> {address, dummy_mapper} end)

    read_mappers = Map.new(mappers)
    write_mappers = Map.new(mappers)

    assert :ok = Memory.set_read_mappers(read_mappers)
    assert :ok = Memory.set_write_mappers(write_mappers)

    for address <- 0x0200..0x3FFF do
      assert {:ok, "DUMMY MAPPER"} = Memory.read(address)
    end
  end
end
