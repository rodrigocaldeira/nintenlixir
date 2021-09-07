defmodule Nintenlixir.PPU.OAMTest do
  use ExUnit.Case

  alias Nintenlixir.Memory
  alias Nintenlixir.PPU.OAM

  @basic_memory_name :oam_basic_memory
  @buffer_name :oam_buffer

  @initial_state %{
    address: 0x0000,
    latch: 0x00,
    sprite_zero_in_buffer: false,
    index: 0x0000,
    write_cycle: :fail_copy_y_position
  }

  setup do
    start_supervised!({Memory, @basic_memory_name}, id: @basic_memory_name)
    start_supervised!({Memory, @buffer_name}, id: @buffer_name)
    start_supervised(OAM)
    :ok
  end

  test "OAM.get_state/0" do
    assert @initial_state = OAM.get_state()
  end

  test "OAM.set_state/1" do
    assert :ok = OAM.set_state(%{@initial_state | address: 0xCAFE})
    assert %{address: 0xCAFE} = OAM.get_state()
  end

  test "OAM.read/1" do
    assert :ok = Memory.write(@basic_memory_name, 0xCAFE, 0x0E)
    assert {:ok, 0x0E} = OAM.read(0xCAFE)
  end

  test "OAM.read_buffer/1" do
    assert :ok = Memory.write(@buffer_name, 0xCAFE, 0x0E)
    assert {:ok, 0x0E} = OAM.read_buffer(0xCAFE)
  end

  test "OAM.write/2" do
    assert :ok = OAM.write(0xCAFE, 0x0E)
    assert {:ok, 0x0E} = Memory.read(@basic_memory_name, 0xCAFE)
  end

  test "OAM.write_buffer/2" do
    assert :ok = OAM.write_buffer(0xCAFE, 0x0E)
    assert {:ok, 0x0E} = Memory.read(@buffer_name, 0xCAFE)
  end

  test "OAM.increment_address/1" do
    assert :ok = OAM.increment_address(0x00FF)
    assert %{address: 0x0001} = OAM.get_state()
  end

  test "OAM.fetch_address/0" do
    assert :ok = Memory.write(@basic_memory_name, 0x0000, 0x0E)
    assert :ok = OAM.fetch_address()
    assert %{latch: 0x0E} = OAM.get_state()

    assert :ok = Memory.write(@basic_memory_name, 0x0100, 0x0E)
    assert :ok = OAM.set_state(%{@initial_state | address: 0x0100})
    assert %{latch: 0x00} = OAM.get_state()
  end

  test "OAM.clear_buffer/0" do
    assert :ok = OAM.set_state(%{@initial_state | latch: 0x12})
    assert :ok = Memory.write(@basic_memory_name, 0x0000, 0x0E)
    assert :ok = OAM.clear_buffer()
    assert %{address: 0x0001} = OAM.get_state()
    assert {:ok, 0x12} = Memory.read(@buffer_name, 0x0000)
  end

  test "OAM.copy_y_position/2 with success" do
    assert :ok = OAM.set_state(%{@initial_state | latch: 0x03})
    assert :ok = OAM.copy_y_position(7, 8)
    assert %{address: 0x0001, write_cycle: :copy_index} = OAM.get_state()
    assert {:ok, 0x03} = Memory.read(@buffer_name, 0x0000)
  end

  test "OAM.copy_y_position/2 failing" do
    assert :ok = OAM.copy_y_position(0, 0)
    assert %{address: 0x0004} = OAM.get_state()
  end

  test "OAM.copy_y_position/2 failing with overflow" do
    assert :ok = OAM.set_state(%{@initial_state | address: 0x00FC})
    assert :ok = OAM.copy_y_position(0, 0)
    assert %{address: 0x0100, write_cycle: :fail_copy_y_position} = OAM.get_state()
  end

  test "OAM.copy_index/0" do
    assert :ok = OAM.set_state(%{@initial_state | latch: 0x12})
    assert :ok = OAM.copy_index()
    assert %{address: 0x0001, write_cycle: :copy_attributes} = OAM.get_state()
    assert {:ok, 0x12} = Memory.read(@buffer_name, 0x0001)
  end

  test "OAM.copy_attributes/0" do
    assert :ok = OAM.set_state(%{@initial_state | latch: 0x12})
    assert :ok = OAM.copy_attributes()
    assert %{address: 0x0001, write_cycle: :copy_x_position} = OAM.get_state()
    assert {:ok, 0x12} = Memory.read(@buffer_name, 0x0002)
  end

  test "OAM.copy_x_position/0 with index < 0x0020" do
    assert :ok = OAM.set_state(%{@initial_state | latch: 0x12})
    assert :ok = OAM.copy_x_position()

    assert %{
             address: 0x0001,
             write_cycle: :copy_y_position,
             index: 0x0004,
             sprite_zero_in_buffer: true
           } = OAM.get_state()

    assert {:ok, 0x12} = Memory.read(@buffer_name, 0x0003)
  end

  test "OAM.copy_x_position/0 with index >= 0x0020" do
    assert :ok = OAM.set_state(%{@initial_state | address: 0x00FD, index: 0x0020, latch: 0x12})
    assert :ok = OAM.copy_x_position()

    assert %{
             address: 0x00FC,
             write_cycle: :evaluate_y_position,
             index: 0x0024,
             sprite_zero_in_buffer: false
           } = OAM.get_state()

    assert {:ok, 0x12} = Memory.read(@buffer_name, 0x0023)
    assert {:error, :cannot_write} = Memory.write(@buffer_name, 0x0023, 0xFF)
  end

  test "OAM.evaluate_y_position/2 with sprite overflow" do
    assert :sprite_overflow = OAM.evaluate_y_position(0, 10)
    assert %{address: 0x0001, write_cycle: :evaluate_index} = OAM.get_state()
  end

  test "OAM.evaluate_y_position/2 with resulting address > 0x0005" do
    assert :ok = OAM.set_state(%{@initial_state | address: 0x0007})
    assert :ok = OAM.evaluate_y_position(0, 0)
    assert %{address: 0x0008} = OAM.get_state()
  end

  test "OAM.evaluate_y_position/2 with resulting address <= 0x0005" do
    assert :ok = OAM.evaluate_y_position(0, 0)
    assert %{address: 0x0004} = OAM.get_state()
  end

  test "OAM.evaluate_index/0" do
    assert :ok = OAM.evaluate_index()
    assert %{address: 0x0001, write_cycle: :evaluate_attributes} = OAM.get_state()
  end

  test "OAM.evaluate_attributes/0" do
    assert :ok = OAM.evaluate_attributes()
    assert %{address: 0x0001, write_cycle: :evaluate_x_position} = OAM.get_state()
  end

  test "OAM.evaluate_x_position/0" do
    assert :ok = OAM.evaluate_x_position()
    assert %{address: 0x0000, write_cycle: :fail_copy_y_position} = OAM.get_state()
  end

  test "OAM.evaluate_x_position/0 with double address increment" do
    assert :ok = OAM.set_state(%{@initial_state | address: 0x0007})
    assert :ok = OAM.evaluate_x_position()
    assert %{address: 0x0008, write_cycle: :fail_copy_y_position} = OAM.get_state()
  end

  test "OAM.fail_copy_y_position/0" do
    assert :ok = OAM.fail_copy_y_position()
    assert %{address: 0x0004} = OAM.get_state()
  end

  test "OAM.sprite/1" do
    address = 0x0000

    assert :ok = OAM.write_buffer(address, 0x00)
    assert :ok = OAM.write_buffer(address + 1, 0x01)
    assert :ok = OAM.write_buffer(address + 2, 0x02)
    assert :ok = OAM.write_buffer(address + 3, 0x03)

    assert {:ok, 0x00010203} = OAM.sprite(0)

    address = 0x0004

    assert :ok = OAM.write_buffer(address, 0x04)
    assert :ok = OAM.write_buffer(address + 1, 0x05)
    assert :ok = OAM.write_buffer(address + 2, 0x06)
    assert :ok = OAM.write_buffer(address + 3, 0x07)

    assert {:ok, 0x04050607} = OAM.sprite(1)

    address = 0x001C

    assert :ok = OAM.write_buffer(address, 0xFC)
    assert :ok = OAM.write_buffer(address + 1, 0xFD)
    assert :ok = OAM.write_buffer(address + 2, 0xFE)
    assert :ok = OAM.write_buffer(address + 3, 0xFF)

    assert {:ok, 0xFCFDFEFF} = OAM.sprite(7)
  end

  test "OAM.sprite_evaluation/3 - case 01" do
    Enum.each(0..31, fn address -> OAM.write_buffer(address, 0xFF) end)
    Enum.each(0..63, fn address -> OAM.write(address, 0x00) end)
    Enum.each(65..256, fn cycle -> OAM.sprite_evaluation(0, cycle, 8) end)
    Enum.each(0..31, fn address -> assert {:ok, 0x00} = OAM.read_buffer(address) end)
  end

  test "OAM.sprite_evaluation/3 - case 02" do
    Enum.each(0..31, fn address -> OAM.write_buffer(address, 0xFF) end)

    List.duplicate(0x00, 64)
    |> List.replace_at(4, 0xFF)
    |> List.replace_at(9, 0x01)
    |> List.replace_at(12, 0xFF)
    |> List.replace_at(16, 0xFF)
    |> List.replace_at(21, 0x02)
    |> List.replace_at(24, 0xFF)
    |> List.replace_at(29, 0x03)
    |> List.replace_at(33, 0x04)
    |> List.replace_at(36, 0xFF)
    |> List.replace_at(41, 0x05)
    |> List.replace_at(44, 0xFF)
    |> List.replace_at(48, 0xFF)
    |> List.replace_at(53, 0x06)
    |> List.replace_at(56, 0xFF)
    |> List.replace_at(61, 0x07)
    |> Enum.with_index()
    |> Enum.each(fn {data, address} ->
      OAM.write(address, data)
    end)

    Enum.each(65..256, fn cycle -> OAM.sprite_evaluation(7, cycle, 8) end)

    List.duplicate(0x00, 32)
    |> List.replace_at(5, 0x01)
    |> List.replace_at(9, 0x02)
    |> List.replace_at(13, 0x03)
    |> List.replace_at(17, 0x04)
    |> List.replace_at(21, 0x05)
    |> List.replace_at(25, 0x06)
    |> List.replace_at(29, 0x07)
    |> Enum.with_index()
    |> Enum.each(fn {result_data, address} ->
      assert {:ok, ^result_data} = OAM.read_buffer(address)
    end)
  end

  test "OAM.sprite_evaluation/3 - case 03" do
    Enum.each(0..31, fn address -> OAM.write_buffer(address, 0xFF) end)

    List.duplicate(0x00, 64)
    |> List.replace_at(0, 0x02)
    |> List.replace_at(4, 0xFF)
    |> List.replace_at(8, 0x03)
    |> List.replace_at(9, 0x01)
    |> List.replace_at(10, 0x01)
    |> List.replace_at(11, 0x01)
    |> List.replace_at(12, 0xFF)
    |> List.replace_at(16, 0xFF)
    |> List.replace_at(20, 0x04)
    |> List.replace_at(21, 0x02)
    |> List.replace_at(22, 0x02)
    |> List.replace_at(23, 0x02)
    |> List.replace_at(24, 0xFF)
    |> List.replace_at(28, 0x05)
    |> List.replace_at(29, 0x03)
    |> List.replace_at(30, 0x03)
    |> List.replace_at(31, 0x03)
    |> List.replace_at(32, 0x06)
    |> List.replace_at(33, 0x04)
    |> List.replace_at(34, 0x04)
    |> List.replace_at(35, 0x04)
    |> List.replace_at(36, 0xFF)
    |> List.replace_at(40, 0x07)
    |> List.replace_at(41, 0x05)
    |> List.replace_at(42, 0x05)
    |> List.replace_at(43, 0x05)
    |> List.replace_at(44, 0xFF)
    |> List.replace_at(48, 0xFF)
    |> List.replace_at(52, 0x08)
    |> List.replace_at(53, 0x06)
    |> List.replace_at(54, 0x06)
    |> List.replace_at(55, 0x06)
    |> List.replace_at(56, 0xFF)
    |> List.replace_at(60, 0x09)
    |> List.replace_at(61, 0x07)
    |> List.replace_at(62, 0x07)
    |> List.replace_at(63, 0x07)
    |> Enum.with_index()
    |> Enum.each(fn {data, address} ->
      OAM.write(address, data)
    end)

    Enum.each(65..256, fn cycle -> OAM.sprite_evaluation(9, cycle, 8) end)

    [
      0x02,
      0x00,
      0x00,
      0x00,
      0x03,
      0x01,
      0x01,
      0x01,
      0x04,
      0x02,
      0x02,
      0x02,
      0x05,
      0x03,
      0x03,
      0x03,
      0x06,
      0x04,
      0x04,
      0x04,
      0x07,
      0x05,
      0x05,
      0x05,
      0x08,
      0x06,
      0x06,
      0x06,
      0x09,
      0x07,
      0x07,
      0x07
    ]
    |> Enum.with_index()
    |> Enum.each(fn {result_data, address} ->
      assert {:ok, ^result_data} = OAM.read_buffer(address)
    end)
  end

  test "OAM.sprite_evaluation/3 - case 04" do
    Enum.each(0..31, fn address -> OAM.write_buffer(address, 0xFF) end)

    [
      0x02,
      0x00,
      0x00,
      0x00,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x03,
      0x01,
      0x01,
      0x01,
      0xFF,
      0x00,
      0x00,
      0x00,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x04,
      0x02,
      0x02,
      0x02,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x05,
      0x03,
      0x03,
      0x03,
      0x06,
      0x04,
      0x04,
      0x04,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x07,
      0x05,
      0x05,
      0x05,
      0xFF,
      0x00,
      0x00,
      0x00,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x08,
      0x06,
      0x06,
      0x06,
      0x09,
      0x07,
      0x07,
      0x07,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x02,
      0x00,
      0x00,
      0x00,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x03,
      0x00,
      0x00,
      0x00,
      0xFF,
      0x00,
      0x00,
      0x00,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x04,
      0x00,
      0x00,
      0x00,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x05,
      0x00,
      0x00,
      0x00,
      0x06,
      0x00,
      0x00,
      0x00,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x07,
      0x00,
      0x00,
      0x00,
      0xFF,
      0x00,
      0x00,
      0x00,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x08,
      0x00,
      0x00,
      0x00,
      0x09,
      0x00,
      0x00,
      0x00,
      0xFF,
      0x00,
      0x00,
      0x00
    ]
    |> Enum.with_index()
    |> Enum.each(fn {data, address} ->
      OAM.write(address, data)
    end)

    Enum.each(65..256, fn cycle -> OAM.sprite_evaluation(9, cycle, 8) end)

    [
      0x02,
      0x00,
      0x00,
      0x00,
      0x03,
      0x01,
      0x01,
      0x01,
      0x04,
      0x02,
      0x02,
      0x02,
      0x05,
      0x03,
      0x03,
      0x03,
      0x06,
      0x04,
      0x04,
      0x04,
      0x07,
      0x05,
      0x05,
      0x05,
      0x08,
      0x06,
      0x06,
      0x06,
      0x09,
      0x07,
      0x07,
      0x07
    ]
    |> Enum.with_index()
    |> Enum.each(fn {result_data, address} ->
      assert {:ok, ^result_data} = OAM.read_buffer(address)
    end)
  end

  test "OAM.sprite_evaluation/3 - sprite overflow clear" do
    Enum.each(0..31, fn address -> OAM.write_buffer(address, 0xFF) end)

    [
      0x02,
      0x00,
      0x00,
      0x00,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x03,
      0x01,
      0x01,
      0x01,
      0xFF,
      0x00,
      0x00,
      0x00,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x04,
      0x02,
      0x02,
      0x02,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x05,
      0x03,
      0x03,
      0x03,
      0x06,
      0x04,
      0x04,
      0x04,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x07,
      0x05,
      0x05,
      0x05,
      0xFF,
      0x00,
      0x00,
      0x00,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x08,
      0x06,
      0x06,
      0x06,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x09,
      0x07,
      0x07,
      0x07,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00
    ]
    |> Enum.with_index()
    |> Enum.each(fn {data, address} ->
      OAM.write(address, data)
    end)

    Enum.each(65..256, fn cycle ->
      refute :sprite_overflow == OAM.sprite_evaluation(9, cycle, 8)
    end)
  end

  test "OAM.sprite_evaluation/3 - sprite overflow case 01" do
    Enum.each(0..31, fn address -> OAM.write_buffer(address, 0xFF) end)

    [
      0x02,
      0x00,
      0x00,
      0x00,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x03,
      0x01,
      0x01,
      0x01,
      0xFF,
      0x00,
      0x00,
      0x00,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x04,
      0x02,
      0x02,
      0x02,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x05,
      0x03,
      0x03,
      0x03,
      0x06,
      0x04,
      0x04,
      0x04,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x07,
      0x05,
      0x05,
      0x05,
      0xFF,
      0x00,
      0x00,
      0x00,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x08,
      0x06,
      0x06,
      0x06,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x09,
      0x07,
      0x07,
      0x07,
      0x09,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00
    ]
    |> Enum.with_index()
    |> Enum.each(fn {data, address} ->
      OAM.write(address, data)
    end)

    assert {_, true} =
             Enum.map_reduce(65..256, false, fn cycle, sprite_overflow ->
               sprite_evaluation_result = OAM.sprite_evaluation(9, cycle, 8) == :sprite_overflow
               {sprite_evaluation_result, sprite_overflow || sprite_evaluation_result}
             end)
  end

  test "OAM.sprite_evaluation/3 - sprite overflow case 02" do
    Enum.each(0..31, fn address -> OAM.write_buffer(address, 0xFF) end)

    [
      0x02,
      0x00,
      0x00,
      0x00,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x03,
      0x01,
      0x01,
      0x01,
      0xFF,
      0x00,
      0x00,
      0x00,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x04,
      0x02,
      0x02,
      0x02,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x05,
      0x03,
      0x03,
      0x03,
      0x06,
      0x04,
      0x04,
      0x04,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x07,
      0x05,
      0x05,
      0x05,
      0xFF,
      0x00,
      0x00,
      0x00,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x08,
      0x06,
      0x06,
      0x06,
      0xFF,
      0x00,
      0x00,
      0x00,
      0x09,
      0x07,
      0x07,
      0x07,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x09,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00
    ]
    |> Enum.with_index()
    |> Enum.each(fn {data, address} ->
      OAM.write(address, data)
    end)

    assert {_, true} =
             Enum.map_reduce(65..256, false, fn cycle, sprite_overflow ->
               sprite_evaluation_result = OAM.sprite_evaluation(9, cycle, 8) == :sprite_overflow
               {sprite_evaluation_result, sprite_overflow || sprite_evaluation_result}
             end)
  end
end
