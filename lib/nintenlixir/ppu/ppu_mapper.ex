defmodule Nintenlixir.PPU.PPUMapper do
  use Bitwise

  defstruct name: "PPUMapper"

  alias Nintenlixir.Memory.Mapper
  alias __MODULE__
  alias Nintenlixir.PPU.RP2C02
  alias Nintenlixir.PPU.OAM
  alias Nintenlixir.Memory

  def read(address) when address in 0x2001..0x2007 do
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

        return_value

      _ -> 0x00
    end
  end

  def read(address) do
    case address &&& 0x3F00 do
      0x3F00 ->
        %{palette: palette} = RP2C02.get_state()
        index = address &&& 0x001F
        Enum.at(palette, index)

      _ -> 0x00
    end
  end

  def write(write_address, data) do
    RP2C02.set_state(%{RP2C02.get_state() | latch_value: data})

    case write_address do
      0x2000 ->
        %{
          registers: registers,
          latch_address: latch_address
        } = RP2C02.get_state()
        registers = %{registers | controller: data}
        latch_address = (latch_address &&& 0x73FF) ||| ((data &&& 0x03) <<< 10)
        RP2C02.set_state(%{RP2C02.get_state() | registers: registers, latch_address: latch_address})

      0x2001 ->
        %{registers: registers} = RP2C02.get_state()
        registers = %{registers | mask: data}
        RP2C02.set_state(%{RP2C02.get_state() | registers: registers})

      0x2003 ->
        %{registers: registers} = RP2C02.get_state()
        registers = %{registers | oam_address: data} 
        RP2C02.set_state(%{RP2C02.get_state() | registers: registers})

      0x2004 ->
        %{registers: %{oam_address: oam_address} = registers} = RP2C02.get_state()
        :ok = OAM.write(oam_address, data)
        registers = %{registers | oam_address: oam_address + 1} 
        RP2C02.set_state(%{RP2C02.get_state() | registers: registers})

      0x2005 ->
        %{
          latch: latch,
          latch_address: latch_address,
          registers: registers
        } = RP2C02.get_state()

        if !latch do
          new_address = (latch_address &&& 0x7FE0) ||| ((data >>> 3) &&& 0xFFFF)
          registers = %{registers | scroll: ((data &&& 0x07) &&& 0xFFFF)}
          RP2C02.set_state(%{RP2C02.get_state() | registers: registers, latch_address: new_address})
        else
          RP2C02.set_state(%{RP2C02.get_state() |
            latch_address: (latch_address &&& 0x0C1F) ||| (((data &&& 0xFFFF) <<< 2) ||| (((data &&& 0xFFFF) <<< 12) &&& 0x73E0)
            )
          })
        end

        RP2C02.set_state(%{RP2C02.get_state() | latch: !latch})

      0x2006 ->
        %{
          latch: latch,
          latch_address: latch_address,
          registers: registers
        } = RP2C02.get_state()

        if !latch do
          RP2C02.set_state(%{RP2C02.get_state() |
            latch_address: (latch_address &&& 0x00FF) ||| (((data &&& 0x3F) &&& 0xFFFF) <<< 8)
          })
        else
          new_address = (latch_address &&& 0x7F00) ||| (data &&& 0xFFFF)
          registers = %{registers | address: new_address}
          RP2C02.set_state(%{RP2C02.get_state() |
            registers: registers,
            latch_address: new_address
          })
        end

        RP2C02.set_state(%{RP2C02.get_state() | latch: !latch})

      0x2007 ->
        %{registers: %{address: address}} = RP2C02.get_state()
        Memory.write(:memory_ppu, address &&& 0x3FFF, data)
        RP2C02.increment_address()

      _ -> :ok
    end

    if (write_address &&& 0x3F00) == 0x3F00 do
      index = write_address &&& 0x001F
      %{palette: palette} = RP2C02.get_state()
      palette = List.replace_at(palette, index, data)
      RP2C02.set_state(%{RP2C02.get_state() | palette: palette})

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
