defmodule Nintenlixir.PPU.PPUMapper do
  use Bitwise

  defstruct name: "PPUMapper"

  alias Nintenlixir.Memory.Mapper
  alias __MODULE__
  alias Nintenlixir.PPU.RP2C02
  alias Nintenlixir.PPU.OAM

  def read(address) when address in [0x2001..0x2007] do
    case address do
      0x2001 ->
        %{latch_value: latch_value} = RP2C02.get_state()
        {:ok, latch_value}

      0x2002 ->
        %{
          registers: %{status: status} = registers,
          latch_value: latch_value
        } = RP2C02.get_state()

        return_value = (status &&& 0xE0) ||| (latch_value &&& 0x1F)

        registers = %{registers | status: status &&& (bxor(status, RP2C02.vblank_started()))}
        RP2C02.set_state(%{RP2C02.get_state() | registers: registers, latch: false})

        {:ok, return_value}

      0x2004 ->
        %{registers: %{oam_address: oam_address}} = RP2C02.get_state()
        OAM.read(oam_address)

      0x2007 ->
        %{
          registers: %{
            data: data,
            address: address_registers
          } = registers
        } = RP2C02.get_state()

        return_value = data

        vram_address = address_registers &&& 0x3FFF
        data = RP2C02.read(vram_address)

        return_value = 
          if (vram_address &&& 0x3F00) == 0x3F00 do
            data
          else
            return_value
          end

        registers = %{registers | data: data}
        RP2C02.set_state(%{RP2C02.get_state() | registers: registers})

        RP2C02.increment_address()

        {:ok, return_value}

      _ ->
        {:ok, 0x00}
    end
  end

  def read(address) do
    address &&& 0x3F00
    |> case do
      0x3F00 ->
        %{palette: palette} = RP2C02.get_state()
        index = address &&& 0x001F
        return_value = Enum.at(palette, index)
        {:ok, return_value}

      _ ->
        {:ok, 0x00}
    end
  end

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
