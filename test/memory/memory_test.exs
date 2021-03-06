defmodule Nintenlixir.MemoryTest do
  use ExUnit.Case

  alias Nintenlixir.Memory
  alias Nintenlixir.Memory.DummyMapper

  @processor :processor

  setup do
    start_supervised({Memory, @processor})
    :ok
  end

  test "Memory.read/2 in fresh memory should return 0xff" do
    assert {:ok, 0xFF} == Memory.read(@processor, 0x05)
  end

  test "Memory.read/2 should return error on outbound memory access" do
    assert {:error, :outbound_memory_access} == Memory.read(@processor, -1)
    assert {:error, :outbound_memory_access} == Memory.read(@processor, 70_000)
  end

  test "Memory.write/3 should update the memory" do
    assert :ok = Memory.write(@processor, 0x65, 0x90)
    assert {:ok, 0x90} == Memory.read(@processor, 0x65)
  end

  test "Memory.write/3 should not update the memory on outbound memory access" do
    assert :ok = Memory.write(@processor, -1, 0x90)
    assert {:ok, 0xFF} == Memory.read(@processor, 0xFFFF)
  end

  test "Memory.reset/1 should reset the memory" do
    assert :ok = Memory.write(@processor, 0x65, 0x90)
    assert :ok = Memory.write(@processor, 0x66, 0x91)
    assert :ok = Memory.write(@processor, 0x67, 0x92)
    assert :ok = Memory.write(@processor, 0x68, 0x93)
    assert :ok = Memory.write(@processor, 0x69, 0x94)
    assert :ok = Memory.write(@processor, 0x6AFF, 0x95)

    assert :ok = Memory.reset(@processor)

    assert {:ok, 0xFF} == Memory.read(@processor, 0x65)
    assert {:ok, 0xFF} == Memory.read(@processor, 0x66)
    assert {:ok, 0xFF} == Memory.read(@processor, 0x67)
    assert {:ok, 0xFF} == Memory.read(@processor, 0x68)
    assert {:ok, 0xFF} == Memory.read(@processor, 0x69)
    assert {:ok, 0xFF} == Memory.read(@processor, 0x6AFF)
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
    assert {:ok, 0xFF} = Memory.read(@processor, 0xEFAC)
    assert :ok = Memory.write(@processor, 0xCAFE, 0x0E)
    assert {:ok, 0x0E} = Memory.read(@processor, 0xCAFE)

    mirrors = %{
      0xCAFE => 0xEFAC
    }

    assert :ok = Memory.set_mirrors(@processor, mirrors)

    assert :ok = Memory.write(@processor, 0xCAFE, 0xFA)
    assert {:ok, 0xFA} = Memory.read(@processor, 0xEFAC)

    assert :ok = Memory.write(@processor, 0xEFAC, 0xAE)
    assert {:ok, 0xAE} = Memory.read(@processor, 0xCAFE)
  end

  test "Dummy mapper" do
    dummy_mapper = %DummyMapper{}

    assert :ok = Memory.add_mapper(@processor, dummy_mapper, :cpu)
    assert :ok = Memory.add_mapper(@processor, dummy_mapper, :ppu)

    assert :ok = Memory.write(@processor, 0x1000, 0x003F)
    assert {:ok, 0xCA} = Memory.read(@processor, 0x003F)

    for address <- 0x1000..0x2FFF do
      assert {:ok, "DUMMY MAPPER"} = Memory.read(@processor, address)
    end
  end

  test "Memory.disable_reads/0 and Memory.enable_reads/0" do
    assert :ok = Memory.disable_reads(@processor)
    assert {:error, :cannot_read} = Memory.read(@processor, 0xCAFE)
    assert :ok = Memory.enable_reads(@processor)
    assert {:ok, 0xFF} = Memory.read(@processor, 0xCAFE)
  end

  test "Memory.disable_writes/0 and Memory.enable_writes/" do
    assert :ok = Memory.disable_writes(@processor)
    assert {:error, :cannot_write} = Memory.write(@processor, 0xCAFE, 0x0E)
    assert :ok = Memory.enable_writes(@processor)
    assert :ok = Memory.write(@processor, 0xCAFE, 0x0E)
    assert {:ok, 0x0E} = Memory.read(@processor, 0xCAFE)
  end
end
