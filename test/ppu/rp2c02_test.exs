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
    RP2C02.set_region(:ntsc)
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

  test "RP2C02.address/1" do
    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x00}
    RP2C02.set_state(%{
      RP2C02.get_state() | 
      registers: registers
    })

    PPUMapper.write(0x2006, 0xFF)
    PPUMapper.write(0x2006, 0xFF)
    assert %{registers: %{address: 0x3FFF}} = RP2C02.get_state()

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x00}
    RP2C02.set_state(%{
      RP2C02.get_state() | 
      registers: registers
    })

    assert 0x0000 == RP2C02.fetch_address(1)

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0xFFFF}
    RP2C02.set_state(%{
      RP2C02.get_state() | 
      registers: registers
    })

    assert 0x001F == RP2C02.fetch_address(1)

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x00}
    RP2C02.set_state(%{
      RP2C02.get_state() | 
      registers: registers
    })

    assert 0x0000 == RP2C02.fetch_address(32)

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0xFFFF}
    RP2C02.set_state(%{
      RP2C02.get_state() | 
      registers: registers
    })

    assert 0x001F == RP2C02.fetch_address(32)

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x00}
    RP2C02.set_state(%{
      RP2C02.get_state() | 
      registers: registers
    })

    assert 0x0000 == RP2C02.fetch_address(1024)

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0xFFFF}
    RP2C02.set_state(%{
      RP2C02.get_state() | 
      registers: registers
    })

    assert 0x0003 == RP2C02.fetch_address(1024)

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x00}
    RP2C02.set_state(%{
      RP2C02.get_state() | 
      registers: registers
    })

    assert 0x0000 == RP2C02.fetch_address(4096)

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0xFFFF}
    RP2C02.set_state(%{
      RP2C02.get_state() | 
      registers: registers
    })

    assert 0x0007 == RP2C02.fetch_address(4096)
  end

  test "RP2C02.sprite/2" do
    assert 0x00 = RP2C02.sprite(0x00000000, 1) 
    assert 0xFF = RP2C02.sprite(0xFFFFFFFF, 1) 

    assert 0x00 = RP2C02.sprite(0x00000000, 256) 
    assert 0x01 = RP2C02.sprite(0xFFFFFFFF, 256) 

    assert 0x00 = RP2C02.sprite(0x00000000, 512)
    assert 0xFF = RP2C02.sprite(0xFFFFFFFF, 512)

    assert 0x00 = RP2C02.sprite(0x00000000, 65536)
    assert 0x03 = RP2C02.sprite(0xFFFFFFFF, 65536) 

    assert 0x00 = RP2C02.sprite(0x00000000, 2097152)
    assert 0x01 = RP2C02.sprite(0xFFFFFFFF, 2097152) 

    assert 0x00 = RP2C02.sprite(0x00000000, 4194304)
    assert 0x01 = RP2C02.sprite(0xFFFFFFFF, 4194304) 
    
    assert 0x00 = RP2C02.sprite(0x00000000, 8388608)
    assert 0x01 = RP2C02.sprite(0xFFFFFFFF, 8388608) 

    assert 0x00 = RP2C02.sprite(0x00000000, 16777216)
    assert 0xFF = RP2C02.sprite(0xFFFFFFFF, 16777216) 
  end

  test "PPUMapper.store/2 with 0x2003 address" do
    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | oam_address: 0x00}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers})

    PPUMapper.write(0x2003, 0xFF)

    assert %{registers: %{oam_address: 0xFF}} = RP2C02.get_state()
  end

  test "PPUMapper.store/2 with 0x2004 address" do
    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | oam_address: 0x00}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers})

    Enum.each(0x0000..0x00FF, fn data ->
      PPUMapper.write(0x2004, data)
    end)

    Enum.each(0x0000..0x00FF, fn data ->
      assert {:ok, ^data} = OAM.read(data)
    end)
  end

  test "Palette Mirroring" do
    Enum.each([0x3F10, 0x3F14, 0x3F18, 0x3F1C], fn address ->
      Memory.write(@memory_name, address - 0x0010, 0xFF)

      assert {:ok, 0xFF} = Memory.read(@memory_name, address)

      Memory.write(@memory_name, address - 0x0010, 0x00)
      Memory.write(@memory_name, address, 0xFF)

      assert {:ok, 0xFF} = Memory.read(@memory_name, address - 0x0010)
    end)

    Enum.each(0x3F20..0x3FFF, fn address ->
      Memory.write(@memory_name, address - 0x0020, 0xFF)
      assert {:ok, 0xFF} = Memory.read(@memory_name, address)

      Memory.write(@memory_name, address - 0x0020, 0x00)
      Memory.write(@memory_name, address, 0xFF)

      assert {:ok, 0xFF} = Memory.read(@memory_name, address - 0x0020)
    end)
  end

  test "Address fetch and store logic" do
    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x00}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers})

    PPUMapper.read(0x2002)
    PPUMapper.write(0x2006, 0x3F)
    PPUMapper.write(0x2006, 0xFF)
    
    assert %{registers: %{address: 0x3FFF}} = RP2C02.get_state()

    PPUMapper.read(0x2002)
    PPUMapper.write(0x2006, 0x01)
    PPUMapper.write(0x2006, 0x01)
    
    assert %{registers: %{address: 0x0101}} = RP2C02.get_state()
  end

  test "Data increment 1" do
    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x00}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers})

    PPUMapper.read(0x2002)
    PPUMapper.write(0x2006, 0x01)
    PPUMapper.write(0x2006, 0x00)

    assert %{registers: %{address: 0x0100}} = RP2C02.get_state()

    PPUMapper.write(0x2007, 0xFF)
    PPUMapper.write(0x2007, 0xFF)
    PPUMapper.write(0x2007, 0xFF)

    assert {:ok, 0xFF} = Memory.read(:memory_ppu, 0x0100)
    assert {:ok, 0xFF} = Memory.read(:memory_ppu, 0x0101)
    assert {:ok, 0xFF} = Memory.read(:memory_ppu, 0x0102)
    assert %{registers: %{address: 0x0103}} = RP2C02.get_state()

    Memory.write(:memory_ppu, 0x0103, 0xFF)
    PPUMapper.read(0x2007)
    assert {:ok, 0xFF} = PPUMapper.read(0x2007)
    assert %{registers: %{address: 0x0105}} = RP2C02.get_state()

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x0000}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers})

    PPUMapper.read(0x2002)
    PPUMapper.write(0x2006, 0x3F)
    PPUMapper.write(0x2006, 0x00)
    assert %{registers: %{address: 0x3F00}} = RP2C02.get_state()

    Memory.write(:memory_ppu, 0x3F00, 0xFF)
    Memory.write(:memory_ppu, 0x3F01, 0xFF)
    Memory.write(:memory_ppu, 0x3F02, 0xFF)

    assert {:ok, 0xFF} = PPUMapper.read(0x2007)
    assert %{registers: %{address: 0x3F01}} = RP2C02.get_state()
  end

  test "Data increment 32" do
    PPUMapper.write(0x2000, 0x04)
    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x00}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers})
    PPUMapper.read(0x2002)

    PPUMapper.write(0x2006, 0x01)
    PPUMapper.write(0x2006, 0x00)

    assert %{registers: %{address: 0x0100}} = RP2C02.get_state()

    PPUMapper.write(0x2007, 0xFF)
    PPUMapper.write(0x2007, 0xFF)
    PPUMapper.write(0x2007, 0xFF)

    assert {:ok, 0xFF} = Memory.read(:memory_ppu, 0x0100)
    assert {:ok, 0xFF} = Memory.read(:memory_ppu, 0x0120)
    assert {:ok, 0xFF} = Memory.read(:memory_ppu, 0x0140)
  end

  test "RP2C02.increment_x/0" do
    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x00}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers})

    RP2C02.increment_x()

    assert %{registers: %{address: 0x0001}} = RP2C02.get_state()

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x1E}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers})

    RP2C02.increment_x()

    assert %{registers: %{address: 0x001F}} = RP2C02.get_state()

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x001F}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers})

    RP2C02.increment_x()

    assert %{registers: %{address: 0x0400}} = RP2C02.get_state()

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x041F}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers})

    RP2C02.increment_x()

    assert %{registers: %{address: 0x0000}} = RP2C02.get_state()
  end

  test "RP2C02.transfer_x/0" do
    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x7BE0}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers, latch_address: 0x041F})

    RP2C02.transfer_x()

    assert %{registers: %{address: 0x7FFF}} = RP2C02.get_state()

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x7BE0}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers, latch_address: 0xFFFF})

    RP2C02.transfer_x()

    assert %{registers: %{address: 0x7FFF}} = RP2C02.get_state()

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0xFFFF}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers, latch_address: 0x0000})

    RP2C02.transfer_x()

    assert %{registers: %{address: 0x7BE0}} = RP2C02.get_state()

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x0000}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers, latch_address: 0xFFFF})

    RP2C02.transfer_x()

    assert %{registers: %{address: 0x041F}} = RP2C02.get_state()
  end

  test "RP2C02.increment_y/0" do
    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x0000}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers})

    RP2C02.increment_y()

    assert %{registers: %{address: 0x1000}} = RP2C02.get_state()

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x1000}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers})

    RP2C02.increment_y()

    assert %{registers: %{address: 0x2000}} = RP2C02.get_state()

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x6000}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers})

    RP2C02.increment_y()

    assert %{registers: %{address: 0x7000}} = RP2C02.get_state()

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x7000}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers})

    RP2C02.increment_y()

    assert %{registers: %{address: 0x0020}} = RP2C02.get_state()

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x73D0}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers})

    RP2C02.increment_y()

    assert %{registers: %{address: 0x03F0}} = RP2C02.get_state()

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x7FA0}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers})

    RP2C02.increment_y()

    assert %{registers: %{address: 0x0400}} = RP2C02.get_state()

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x73A0}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers})

    RP2C02.increment_y()

    assert %{registers: %{address: 0x0800}} = RP2C02.get_state()

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x73E1}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers})

    RP2C02.increment_y()

    assert %{registers: %{address: 0x0001}} = RP2C02.get_state()
  end

  test "RP2C02.transfer_y/0" do
    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x041F}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers, latch_address: 0x7BE0})

    RP2C02.transfer_y()

    assert %{registers: %{address: 0x7FFF}} = RP2C02.get_state()

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x041F}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers, latch_address: 0xFFFF})

    RP2C02.transfer_y()

    assert %{registers: %{address: 0x7FFF}} = RP2C02.get_state()

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0xFFFF}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers, latch_address: 0x0000})

    RP2C02.transfer_y()

    assert %{registers: %{address: 0x041F}} = RP2C02.get_state()

    %{registers: registers} = RP2C02.get_state()
    registers = %{registers | address: 0x0000}
    RP2C02.set_state(%{RP2C02.get_state() | registers: registers, latch_address: 0xFFFF})

    RP2C02.transfer_y()

    assert %{registers: %{address: 0x7BE0}} = RP2C02.get_state()
  end
end
