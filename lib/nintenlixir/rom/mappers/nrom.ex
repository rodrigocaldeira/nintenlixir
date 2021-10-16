defmodule Nintenlixir.ROM.Mappers.NROM do
  use Bitwise

  defstruct name: "NROM"

  alias Nintenlixir.Memory.Mapper
  alias Nintenlixir.ROM
  alias __MODULE__

  # Mapper

  defimpl Mapper, for: NROM do
    def build_mappings(mapper, :ppu) do
      %ROM{chr_banks: chr_banks} = ROM.get_state()

      if chr_banks > 0 do
        Enum.map(0x0000..0x1FFF, fn address -> {address, mapper} end)
        |> Map.new()
      else
        nil
      end
    end

    def build_mappings(mapper, :cpu) do
      %ROM{prg_banks: prg_banks} = ROM.get_state()

      if prg_banks > 0 do
        Enum.map(0x8000..0xFFFF, fn address -> {address, mapper} end)
        |> Map.new()
      else
        nil
      end
    end

    def write(_mapper, address, data, memory) when address in 0x0000..0x1FFFF do
      %ROM{chr_banks: chr_banks, vrom_banks: vrom_banks} = rom = ROM.get_state()

      if chr_banks > 0 do
        bank = Enum.at(vrom_banks, 0)
        bank = List.replace_at(bank, address, data)
        vrom_banks = List.replace_at(vrom_banks, 0, bank)
        rom = %{rom | vrom_banks: vrom_banks}
        ROM.set_state(rom)
      end

      memory
    end

    def write(_mapper, _address, _data, memory), do: memory

    def read(_mapper, address, _memory) when address in 0x0000..0x1FFF do
      IO.inspect(address)
      %ROM{chr_banks: chr_banks, vrom_banks: vrom_banks} = ROM.get_state()

      if chr_banks > 0 do
        bank = Enum.at(vrom_banks, 0)
        Enum.at(bank, address)
      else
        0x00
      end
      |> IO.inspect()
    end

    def read(_mapper, address, _memory) when address in 0x8000..0xFFFF do
      IO.inspect("ROM")
      IO.inspect(address)
      %ROM{prg_banks: prg_banks, rom_banks: rom_banks} = ROM.get_state()

      if prg_banks > 0 do
        index = address &&& 0x3FFF

        bank_index =
          case address do
            address when address in 0x8000..0xBFFF ->
              0

            _ ->
              prg_banks - 1
          end

        bank = Enum.at(rom_banks, bank_index)
        Enum.at(bank, index)
      else
        0x00
      end
      |> IO.inspect()
    end

    def read(_mapper, _address, _memory), do: 0x00
  end
end
