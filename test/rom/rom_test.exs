defmodule Nintenlixir.ROMTest do
  use ExUnit.Case

  alias Nintenlixir.ROM
  alias Nintenlixir.CPU.MOS6502
  alias Nintenlixir.PPU.NameTableMapper

  setup do
    start_supervised(ROM)
    start_supervised(NameTableMapper)
    :ok
  end

  test "ROM.load/1" do
    ROM.load(test_file(), &MOS6502.irq/0, &NameTableMapper.set_tables/1)

    ROM.get_state()
    # |> IO.inspect()
  end

  def test_file do
    Path.join(:code.priv_dir(:nintenlixir), 'nestest.nes')
  end
end
