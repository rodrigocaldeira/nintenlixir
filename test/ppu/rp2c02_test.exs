defmodule Nintenlixir.PPU.RP2C02Test do
  use ExUnit.Case

  alias Nintenlixir.PPU.RP2C02
  alias Nintenlixir.Memory
  alias Nintenlixir.PPU.OAM
  alias Nintenlixir.PPU.NameTableMapper
  alias Nintenlixir.CPU.MOS6502

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
end
