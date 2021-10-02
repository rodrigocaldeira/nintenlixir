defmodule Nintenlixir.PPU.RP2C02Test do
  use ExUnit.Case
  use Bitwise

  alias Nintenlixir.PPU.RP2C02
  alias Nintenlixir.Memory
  alias Nintenlixir.PPU.OAM
  alias Nintenlixir.PPU.NameTableMapper
  alias Nintenlixir.CPU.MOS6502
  alias Nintenlixir.PPU.PPUMapper

  @basic_memory_name :oam_basic_memory
  @buffer_name :oam_buffer
  @memory_name :memory_ppu

  setup do
    start_supervised!({Memory, @basic_memory_name}, id: @basic_memory_name)
    start_supervised!({Memory, @buffer_name}, id: @buffer_name)
    start_supervised!({Memory, @memory_name}, id: @memory_name)
    start_supervised(OAM)
    start_supervised(NameTableMapper)
    start_supervised(MOS6502)
    start_supervised!(RP2C02)
    :ok
  end

  test "RP2C02.get_state/0" do
    RP2C02.get_state() 
    # |> IO.inspect()
  end

  test "RP2C02.set_region/1" do
    assert :ok = RP2C02.set_region(:pal)
    assert %{region: :pal} = RP2C02.get_state()

    assert :ok = RP2C02.set_region(:ntsc)
    assert %{region: :ntsc} = RP2C02.get_state()
  end

  test "RP2C02.num_scanlines/0" do
    assert :ok = RP2C02.set_region(:pal)
    assert 312 = RP2C02.num_scanlines()

    assert :ok = RP2C02.set_region(:ntsc)
    assert 262 = RP2C02.num_scanlines()
  end

  test "RP2C02.pre_render_scanline/0" do
    assert :ok = RP2C02.set_region(:pal)
    assert 311 = RP2C02.pre_render_scanline()

    assert :ok = RP2C02.set_region(:ntsc)
    assert 261 = RP2C02.pre_render_scanline()
  end

  test "RP2C02.controller/1" do
    assert :ok = RP2C02.set_region(:ntsc)
    %{
      registers: registers
    } = state = RP2C02.get_state()

    registers = %{registers | controller: 0x00}
    RP2C02.set_state(%{state | registers: registers})

    PPUMapper.write(0x2000, 0xFF)
    assert %{registers: %{controller: 0xFF}} = RP2C02.get_state()

    registers = %{registers | controller: 0xFF - 0x03}
    RP2C02.set_state(%{state | registers: registers})
    assert 0x2000 = RP2C02.controller(1)

    registers = %{registers | controller: 0xFF - 0x02}
    RP2C02.set_state(%{state | registers: registers})
    assert 0x2400 = RP2C02.controller(1)

    registers = %{registers | controller: 0xFF - 0x01}
    RP2C02.set_state(%{state | registers: registers})
    assert 0x2800 = RP2C02.controller(1)

    registers = %{registers | controller: 0xFF}
    RP2C02.set_state(%{state | registers: registers})
    assert 0x2c00 = RP2C02.controller(1)

    registers = %{registers | controller: ~~~(4) &&& 0xFF}
    RP2C02.set_state(%{state | registers: registers})
    assert 1 = RP2C02.controller(4)

    registers = %{registers | controller: 4 &&& 0xFF}
    RP2C02.set_state(%{state | registers: registers})
    assert 32 = RP2C02.controller(4)

    registers = %{registers | controller: 8}
    RP2C02.set_state(%{state | registers: registers})
    assert 0x1000 = RP2C02.controller(8)

    registers = %{registers | controller: ~~~(16) &&& 0xFF}
    RP2C02.set_state(%{state | registers: registers})
    assert 0x0000 = RP2C02.controller(16)

    registers = %{registers | controller: 16 &&& 0xFF}
    RP2C02.set_state(%{state | registers: registers})
    assert 0x1000 = RP2C02.controller(16)

    registers = %{registers | controller: ~~~(32) &&& 0xFF}
    RP2C02.set_state(%{state | registers: registers})
    assert 8 = RP2C02.controller(32)

    registers = %{registers | controller: 32}
    RP2C02.set_state(%{state | registers: registers})
    assert 16 = RP2C02.controller(32)

    registers = %{registers | controller: ~~~(128) &&& 0xFF}
    RP2C02.set_state(%{state | registers: registers})
    assert 0 = RP2C02.controller(128)

    registers = %{registers | controller: 128}
    RP2C02.set_state(%{state | registers: registers})
    assert 1 = RP2C02.controller(128)
  end

  test "RP2C02.mask/1" do
    assert :ok = RP2C02.set_region(:ntsc)
    %{
      registers: registers
    } = state = RP2C02.get_state()

    registers = %{registers | mask: 0x00}
    RP2C02.set_state(%{state | registers: registers})

    PPUMapper.write(0x2001, 0xFF)
    assert %{registers: %{mask: 0xFF}} = RP2C02.get_state()

    Enum.each([2, 4, 8, 16], fn data ->
      PPUMapper.write(0x2001, data)
      assert RP2C02.mask?(data)
    end)
  end

  test "RP2C02.status/1" do
    assert :ok = RP2C02.set_region(:ntsc)
    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | status: 0xFF}
    RP2C02.set_state(%{
      RP2C02.get_state() | 
      registers: registers,
      latch: true,
      latch_value: 0x00
    })

    assert {:ok, 0xE0} = PPUMapper.read(0x2002)

    assert %{registers: %{status: 0x7F}, latch: false} = RP2C02.get_state()

    Enum.each([32, 64, 128], fn data ->
      %{registers: registers} = RP2C02.get_state()
      registers = %{registers | status: data &&& 0xFF}
      RP2C02.set_state(%{RP2C02.get_state() | registers: registers})
      assert RP2C02.status?(data)
    end)
  end
end
