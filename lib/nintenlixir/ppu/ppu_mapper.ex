defmodule Nintenlixir.PPU.PPUMapper do
  use GenServer
  use Bitwise

  defstruct name: "PPUMapper"

  alias Nintenlixir.Memory.Mapper
  alias __MODULE__
  alias Nintenlixir.PPU.RP2C02
  alias Nintenlixir.PPU.OAM

  # Mapper

  defimpl Mapper, for: PPUMapper do
    def build_mappings(mapper, :ppu) do
      Enum.map(0x3F00..0x3F1F, fn address -> {address, mapper} end)
      |> Map.new()
    end

    def build_mappings(mapper, :cpu) do
      Enum.map(0x2000..0x2007, fn address -> {address, mapper} end)
    end

    def write(_mapper, address, data, _memory) do
      PPUMapper.write(address, data)
    end

    def read(_mapper, address, _memory) do
      PPUMapper.read(address)
    end
  end
end
