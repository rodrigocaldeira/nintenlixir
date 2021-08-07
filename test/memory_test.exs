defmodule Nintenlixir.MemoryTest do
  use ExUnit.Case

  alias Nintenlixir.Memory

  @processor :processor

  setup do
    # Memory.start_link(@processor)
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
end
