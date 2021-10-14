defmodule Nintenlixir.Console do
  alias Nintenlixir.CPU.MOS6502

  alias Nintenlixir.PPU.{
    PPUMapper,
    RP2C02
  }

  alias Nintenlixir.Memory
  alias Nintenlixir.ROM

  def insert_cartridge(file) do
    ROM.load(file)
  end

  def power_on() do
    reset()
    Memory.add_mapper(MOS6502.memory_server_name(), %PPUMapper{}, :cpu)
    Memory.add_mapper(MOS6502.memory_server_name(), ROM.get_mapper(), :cpu)
    Memory.add_mapper(RP2C02.memory_server_name(), ROM.get_mapper(), :ppu)
    RP2C02.define_interrupt(&MOS6502.nmi/0)
  end

  def reset() do
    MOS6502.reset()
    RP2C02.reset()
  end
end
