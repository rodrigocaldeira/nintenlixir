defmodule Nintenlixir.PPU.RP2C02 do
  use GenServer
  use Bitwise

  @horizontal_mirroring 0
  @vertical_mirroring 1
  @four_screen_mirroring 2

  @base_name_table_address 1
  @vram_address_increment 4
  @sprite_pattern_address 8
  @background_pattern_address 16
  @sprite_size 32
  @nmi_on_vblank 128

  @gray_scale 1
  @show_background_left 2
  @show_sprites_left 4
  @show_background 8
  @show_sprites 16
  @intensify_reds 32
  @intensify_greens 64
  @intensify_blues 128
  
  @sprite_overflow 32
  @sprite_0_hit 64
  @vblank_started 128

  @coarse_x_scroll 1
  @coarse_y_scroll 32
  @name_table_select 1024
  @fine_y_scroll 4096

  @y_position 1
  @tile_bank 256
  @tile_number 512
  @sprite_palette 65536
  @priority 2097152
  @flip_horizontally 4194304
  @flip_vertically 8388608
  @x_position 16777216

  @cycles_per_scanline 341
  @powerup_scanline 241
  @start_nmi_scanline 241
  @first_visible_scanline 0
  @last_visible_scanline 239
  @num_scanlines_ntsc 262
  @pre_render_scanline_ntsc 261
  @num_scanlines_pal 312
  @pre_render_scanline_pal 311
  @frame_size 0xF000

  @memory_name :memory_ppu
  @oam_basic_memory_bame :oam_basic_memory_ppu
  @oam_buffer_name :oam_buffer_ppu

  alias Nintenlixir.Memory
  alias Nintenlixir.PPU.OAM
  alias Nintenlixir.PPU.NameTableMapper
  alias Nintenlixir.CPU.MOS6502

  def start_link(_) do
    GenServer.start_link(__MODULE__, new_ppu(), name: __MODULE__)
  end

  def get_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  def set_state(state) do
    GenServer.call(__MODULE__, {:set_state, state})
  end

  def num_scanlines do
    get_state()
    |> case do
      %{region: :pal} ->
        @num_scanlines_pal

      _ ->
        @num_scanlines_ntsc
    end
  end

  def pre_render_scanline do
    get_state()
    |> case do
      %{region: :pal} ->
        @pre_render_scanline_pal

      _ ->
        @pre_render_scanline_ntsc
    end
  end

  def set_region(:pal) do
    :ok = set_state(%{get_state() | region: :pal})
  end
  
  def set_region(_) do
    :ok = set_state(%{get_state() | region: :ntsc})
  end

  def trigger_scanline_counter do

  end

  def reset do

  end

  def controller(flag) do
    %{registers: %{controller: controller_register}} = get_state()
    bit = controller_register &&& (flag &&& 0xFF)

    case flag do
      @base_name_table_address ->
        0x2000 ||| ((controller_register &&& 0x03) <<< 10)

      @vram_address_incremet ->
        case bit do
          0 -> 1
          _ -> 32
        end

      @sprite_patter_address ->
        case bit do
          0 -> 0x0000
          _ -> 0x1000
        end

      @background_pattern_address ->
        case bit do
          0 -> 0x0000
          _ -> 0x1000
        end

      @sprite_size ->
        case bit do
          0 -> 8
          _ -> 16
        end

      @nmi_ov_vblank ->
        case bit do
          0 -> 0
          _ -> 1
        end
    end
  end

  def mask?(flag) do
    %{registers: %{mask: mask}} = get_state()
    (mask &&& (flag &&& 0xFF)) != 0
  end

  def status?(flag) do
    %{registers: %{status: status}} = get_state()
    (status &&& (flag &&& 0xFF)) != 0
  end

  def fetch_address(flag) do
    %{registers: %{address: address_register}} = get_state()
    case flag do
      @coarse_x_scroll ->
        address_register &&& 0x001F

      @coarse_y_scroll ->
        (address_register &&& 0x03E0) >>> 5

      @name_table_select ->
        (address_register &&& 0x0C00) >>> 10

      @fine_y_scroll ->
        (address_register &&& 0x7000) >>> 12
    end
  end

  def sprite(sprite_data, @y_position) do
    sprite_data >>> 24
  end

  def sprite(sprite_data, @tile_bank) do
    ((sprite_data &&& 0x00010000) >>> 16) &&& 0xFF
  end

  def sprite(sprite_data, @tile_number) do
    value = ((sprite_data &&& 0x00FF0000) >>> 16) &&& 0xFF

    if controller(@tile_number) == 16 do
      value >>> 1
    else
      value
    end
  end

  def sprite(sprite_data, @sprite_palette) do
    ((sprite_data &&& 0x00000300) >>> 8) &&& 0xFF
  end

  def sprite(sprite_data, @priority) do
    ((sprite_data &&& 0x00002000) >>> 13) &&& 0xFF
  end

  def sprite(sprite_data, @flip_horizontally) do
    ((sprite_data &&& 0x00004000) >>> 14) &&& 0xFF
  end

  def sprite(sprite_data, @flip_vertically) do
    ((sprite_data &&& 0x00008000) >>> 15) &&& 0xFF
  end

  def sprite(sprite_data, @x_position) do
    sprite_data &&& 0xFF
  end

  # TODO: MEMORY MAPPER
  def mappings do

  end

  def read(address) do

  end

  def write(address, data) do

  end

  def transfer_x do
    %{
      registers: %{
        address: address_register
      } = registers,
      latch_address: latch_address
    } = get_state()

    address_register = (address_register &&& 0x7BE0) ||| (latch_address &&& 0x041F)
    registers = %{registers | address: address_register}
    set_state(%{get_state() | registers: registers})
  end
  
  def transfer_y do
    %{
      registers: %{
        address: address_register
      } = registers,
      latch_address: latch_address
    } = get_state()

    address_register = (address_register &&& 0x041F) ||| (latch_address &&& 0x7BE0)
    registers = %{registers | address: address_register}
    set_state(%{get_state() | registers: registers})
  end

  def increment_x do
    %{
      registers: %{
        address: address_register
      } = registers
    } = get_state()

    address_register = 
      case (address_register &&& 0x001F) do
        0x001F ->
          address_register &&& 0x041F

        _ ->
          address_register + 1
      end
    
    registers = %{registers | address: address_register}
    set_state(%{get_state() | registers: registers})
  end

  def increment_y do
    %{
      registers: %{
        address: address_register
      } = registers
    } = get_state()

    address_register = 
      if (address_register &&& 0x7000) != 0x7000 do
        address_register + 0x1000
      else

        case (address_register &&& 0x03E0) do
          0x03A0 ->
            bxor(address_register, 0x0BA0)
          
          0x03E0 ->
            bxor(address_register, 0x03E0)

          _ ->
            address_register + 0x0020
        end
      end
    
    registers = %{registers | address: address_register}
    set_state(%{get_state() | registers: registers})
  end
  
  def increment_address do
    %{
      scanline: scanline,
      pre_render_scanline: pre_render_scanline,
      registers: %{
        address: address_register
      } = registers
    } = get_state()

    controller_result = controller(@vram_address_increment)

    cond do
      (scanline > @last_visible_scanline && scanline != pre_render_scanline) || !rendering?() ->
        address_register = address_register + controller_result

        registers = %{registers | address: address_register}
        set_state(%{get_state() | registers: registers})

      true ->
        increment_address(@vram_address_increment)
    end
  end

  def increment_address(32), do: increment_y()

  def increment_address(_) do
    %{
      registers: %{
        address: address_register
      } = registers
    } = get_state()

    address_register = address_register + 1

    registers = %{registers | address: address_register}
    set_state(%{get_state() | registers: registers})
  end

  def rendering? do
    mask?(@show_background) || mask?(@show_sprites)
  end

  def fetch_background do
    %{
      cycle: cycle,
      attribute_latch: attribute_latch,
      attribute_next: attribute_next,
      attributes: attributes,
      tiles_low: tiles_low,
      tiles_high: tiles_high,
      tiles_latch_low: tiles_latch_low,
      tiles_latch_high: tiles_latch_high,
      tile_data: tile_data,
      palette: palette
    } = get_state()

    case cycle &&& 0x07 do
      0x01 ->
        attribute_latch = attribute_next <<< 2
        bg_attribute = attributes &&& 0xFFFF

        Enum.each([0.15], fn i -> 
          bg_index = 0

          case i do
            8 ->
              bg_attribute = attribute_latch &&& 0xFFFF
              tiles_low = tiles_latch_low
              tiles_high = tiles_latch_high
          end

          bg_index = 
            case tiles_high &&& 0x80 do
              0 -> bg_index
              _ -> bg_index ||| 2
            end

          bg_index = 
            case tiles_low &&& 0x80 do
              0 -> bg_index
              _ -> bg_index ||| 1
            end

          tile_data = 
            List.update_at(tile_data, i, fn tile ->
              %{tile | 
                pixel: Enum.at(palette, 0x3F1F &&& (bg_attribute ||| bg_index)),
                index: bg_index &&& 0xFF
              }
            end)

            tiles_low = tiles_low <<< 1
            tiles_high = tiles_high <<< 1
        end)

        tiles_low = tiles_latch_low
        tiles_high = tiles_latch_high
        attributes = attribute_latch &&& 0xFFFF

        set_state(%{get_state() |
          attribute_latch: attribute_latch,
          attributes: attributes,
          tiles_low: tiles_low,
          tiles_high: tiles_high,
          tile_data: tile_data
        })
    end
  end

  def reverse_sprite(sprite) do
    sprite = ((sprite &&& 0x55) <<< 1) ||| ((sprite &&& 0xAA) >>> 1)
    sprite = ((sprite &&& 0x33) <<< 2) ||| ((sprite &&& 0xCC) >>> 2)
    ((sprite &&& 0x0F) <<< 4) ||| ((sprite &&& 0xF0) >>> 4)
  end

  def fetch_sprites do
    %{
      cycle: cycle,
      sprites: sprites
    } = get_state()

    case cycle &&& 0x01C7 do
      0x0107 ->
        index = ((cycle >>> 3) &&& 0x07) &&& 0xFF
        oam_sprite = OAM.sprite(index)

        x_position = sprite(oam_sprite, @x_position)
        %{sprite_zero_in_buffer: sprite_zero_in_buffer} = OAM.get_state()
        zero = index == 0 && sprite_zero_in_buffer

        address = sprite_address(oam_sprite)
        {:ok, tile_low} = read(address)
        {:ok, tile_high} = read(address ||| 0x0008)

        {tile_low, tile_high} = 
          case sprite(oam_sprite, @flip_horizontally) do
            0 ->
              {tile_low, tile_high}

            _ ->
              {reverse_sprite(tile_low), reverse_sprite(tile_high)}
          end

        attribute = (sprite(oam_sprite, @sprite_palette) <<< 2) &&& 0xFFFF

        address = (0x3F10 ||| attribute) &&& 0xFFFF
        priority = sprite(oam_sprite, @priority)

        temp_tile_low = tile_low
        temp_tile_high = tile_high

        tile_data = List.duplicate(%{pixel: 0x00, index: 0x00}, 8)

        Enum.map([0..7], fn i ->
          high = temp_tile_high &&& 0x80
          low = temp_tile_low &&& 0x80

          pindex = address ||| (((high >>> 6) ||| (low >>> 7)) &&& 0xFFFF)
          {:ok, pixel} = read(0x3F00 ||| (pindex &&& 0x001F))
          List.update_at(tile_data, i, fn tile ->
            %{tile |
              pixel: pixel,
              index: pindex &&& 0x0003
            }
          end)

          temp_tile_low = temp_tile_low <<< 1
          temp_tile_high = temp_tile_high <<< 1
        end)

        List.update_at(sprites, index, fn s ->
          %{s |
            tile_low: tile_low,
            tile_high: tile_high,
            sprite: oam_sprite,
            x_position: x_position,
            address: address,
            priority: priority,
            zero: zero,
            tile_data: tile_data
          }
        end)

        set_state(%{get_state() | sprites: sprites})
    end
  end

  def open_name(address), do: 0x2000 ||| (address &&& 0x0FFF)

  def fetch_name(address) do
    {:ok, data} = read(address)
    controller(@background_pattern_address) ||| (data <<< 4) ||| fetch_address(@fine_y_scroll)
  end

  def open_attribute(address) do
    0x23C0 ||| (address &&& 0x0C00) ||| ((address >>> 4) &&& 0x0038) ||| ((address >>> 2) &&& 0x0007)
  end

  def fetch_attribute(address) do
    {:ok, data} = read(address)
    %{
      registers: %{
        address: address_register
      }
    } = get_state()
    data >>> (((address_register &&& 0x02) ||| ((address_register >>> 0x04) &&& 0x04)) &&& 0x03)
  end

  def sprite_address(sprite) do

  end

  def priority_multiplexer(bg_pixel, bg_index, sprite_pixel, sprite_index, sprite_priority) do

  end

  def render_background do

  end

  def render_sprites do

  end

  def open_nt_byte do

  end

  def fetch_nt_byte do

  end

  def open_at_byte do

  end

  def fetch_at_byte do
    
  end

  def open_low_bg_tile_byte do

  end

  def fetch_low_bg_tile_byte do

  end

  def open_high_bg_tile_byte do

  end

  def fetch_high_bg_tile_byte do

  end

  def set_hori_v do

  end

  def set_vert_v do

  end

  def init_cycle_jump_table do

  end

  def render_visible_scanline do

  end

  def execute do
  
  end

  def get_pattern_tables do

  end

  def save_pattern_tables do

  end

  # Server

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_state, _, state), do: {:reply, state, state}

  def handle_call({:set_state, state}, _, _), do: {:reply, :ok, state}

  # Helpers

  defp new_ppu do
    %{
      colors: List.duplicate(0x00, @frame_size),
      show_background: true,
      show_sprites: true,
      frame: 0x0000,
      scanline: 0x0000,
      cycle: 0x0000,
      registers: %{
        controller: 0x00,
        mask: 0x00,
        status: 0x00,
        oam_address: 0x00,
        scroll: 0x00,
        address: 0x00,
        data: 0x00
      },
      palette: List.duplicate(0x00, 32),
      latch: false,
      latch_address: 0x0000,
      latch_value: 0x00,
      address_line: 0x0000,
      pattern_address: 0x0000,
      attribute_next: 0x00,
      attribute_latch: 0x00,
      attributes: 0x0000,
      tiles_low: 0x00,
      tiles_high: 0x00,
      tiles_latch_low: 0x00,
      tiles_latch_high: 0x00,
      tile_data: List.duplicate(%{pixel: 0x00, index: 0x00}, 16),
      sprites: List.duplicate(%{
        tile_low: 0x00,
        tile_high: 0x00,
        sprite: 0x00000000,
        x_position: 0x00,
        address: 0x0000,
        priority: 0x00,
        zero: false,
        tile_data: List.duplicate(%{pixel: 0x00, index: 0x00}, 8)
      }, 8),
      region: :pal,
      num_scanlines: 0x0000,
      pre_render_scanline: 0x0000
    }
  end
end
