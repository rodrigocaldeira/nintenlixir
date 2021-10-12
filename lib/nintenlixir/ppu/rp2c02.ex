defmodule Nintenlixir.PPU.RP2C02 do
  use GenServer
  use Bitwise

  # @horizontal_mirroring 0
  # @vertical_mirroring 1
  # @four_screen_mirroring 2

  @base_name_table_address 1
  @vram_address_increment 4
  @sprite_pattern_address 8
  @background_pattern_address 16
  @sprite_size 32
  @nmi_on_vblank 128

  # @gray_scale 1
  @show_background_left 2
  @show_sprites_left 4
  @show_background 8
  @show_sprites 16
  # @intensify_reds 32
  # @intensify_greens 64
  # @intensify_blues 128

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
  @priority 2_097_152
  @flip_horizontally 4_194_304
  @flip_vertically 8_388_608
  @x_position 16_777_216

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

  alias Nintenlixir.Memory
  alias Nintenlixir.PPU.OAM
  alias Nintenlixir.PPU.NameTableMapper
  # alias Nintenlixir.CPU.MOS6502
  alias Nintenlixir.PPU.PPUMapper

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
    %{
      scanline: scanline,
      cycle: cycle
    } = get_state()

    if scanline >= @first_visible_scanline && scanline <= @last_visible_scanline && rendering?() do
      sprite_address = controller(@sprite_pattern_address)
      bg_address = controller(@background_pattern_address)

      cycle == 262 &&& bg_address == 0x0000 && sprite_address == 0x1000
    else
      false
    end
  end

  def reset do
    set_state(%{
      get_state()
      | registers: new_registers(),
        latch: false,
        frame: 0x00,
        cycle: 0x00,
        scanline: @powerup_scanline
    })

    Memory.reset(@memory_name)

    start_memory()
  end

  def start_memory do
    mirrors1 =
      Enum.map(0x3000..0x3EFF, fn address ->
        {address, address - 0x1000}
      end)
      |> Map.new()

    mirrors2 =
      Enum.map([0x3F10, 0x3F14, 0x3F18, 0x3F1C], fn address ->
        {address, address - 0x0010}
      end)
      |> Map.new()

    mirrors3 =
      Enum.map(0x3F20..0x3FFF, fn address ->
        {address, 0x3F00 + (address &&& 0x001F)}
      end)
      |> Map.new()

    mirrors =
      mirrors1
      |> Map.merge(mirrors2)
      |> Map.merge(mirrors3)

    Memory.set_mirrors(@memory_name, mirrors)

    name_table_mapper = %NameTableMapper{}
    Memory.add_mapper(@memory_name, name_table_mapper, :ppu)

    ppu_mapper = %PPUMapper{}
    Memory.add_mapper(@memory_name, ppu_mapper, :ppu)
  end

  def define_interrupt(interrupt) do
    set_state(%{get_state() | interrupt: interrupt})
  end

  def vblank_started, do: @vblank_started

  def controller(flag) do
    %{registers: %{controller: controller_register}} = get_state()
    bit = controller_register &&& (flag &&& 0xFF)

    case flag do
      @base_name_table_address ->
        0x2000 ||| (controller_register &&& 0x03) <<< 10

      @vram_address_increment ->
        case bit do
          0 -> 1
          _ -> 32
        end

      @sprite_pattern_address ->
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

      @nmi_on_vblank ->
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
    (sprite_data &&& 0x00010000) >>> 16 &&& 0xFF
  end

  def sprite(sprite_data, @tile_number) do
    value = (sprite_data &&& 0x00FF0000) >>> 16 &&& 0xFF

    if controller(@sprite_size) == 16 do
      value >>> 1
    else
      value
    end
  end

  def sprite(sprite_data, @sprite_palette) do
    (sprite_data &&& 0x00000300) >>> 8 &&& 0xFF
  end

  def sprite(sprite_data, @priority) do
    (sprite_data &&& 0x00002000) >>> 13 &&& 0xFF
  end

  def sprite(sprite_data, @flip_horizontally) do
    (sprite_data &&& 0x00004000) >>> 14 &&& 0xFF
  end

  def sprite(sprite_data, @flip_vertically) do
    (sprite_data &&& 0x00008000) >>> 15 &&& 0xFF
  end

  def sprite(sprite_data, @x_position) do
    sprite_data &&& 0xFF
  end

  def define_mappings(processor) do
    ppu_mapper = %PPUMapper{}
    :ok = Memory.add_mapper(@memory_name, ppu_mapper, processor)
  end

  def read(address) do
    Memory.read(@memory_name, address)
  end

  def write(address, data) do
    Memory.write(@memory_name, address, data)
  end

  def transfer_x do
    %{
      registers:
        %{
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
      registers:
        %{
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
      registers:
        %{
          address: address_register
        } = registers
    } = get_state()

    address_register =
      case address_register &&& 0x001F do
        0x001F ->
          bxor(0x041F, address_register)

        _ ->
          address_register + 1
      end

    registers = %{registers | address: address_register}
    set_state(%{get_state() | registers: registers})
  end

  def increment_y do
    %{
      registers:
        %{
          address: address_register
        } = registers
    } = get_state()

    address_register =
      if (address_register &&& 0x7000) != 0x7000 do
        address_register + 0x1000
      else
        new_address_register = address_register &&& 0x0FFF

        case new_address_register &&& 0x03E0 do
          0x03A0 ->
            bxor(new_address_register, 0x0BA0)

          0x03E0 ->
            bxor(new_address_register, 0x03E0)

          _ ->
            new_address_register + 0x0020
        end
      end

    registers = %{registers | address: address_register}
    set_state(%{get_state() | registers: registers})
  end

  def increment_address do
    %{
      scanline: scanline,
      pre_render_scanline: pre_render_scanline,
      registers:
        %{
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
      registers:
        %{
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

        Enum.reduce(
          0..15,
          %{
            tiles_low: tiles_low,
            tiles_high: tiles_high
          },
          fn i, %{tiles_low: tiles_low, tiles_high: tiles_high} ->
            bg_index = 0

            %{
              bg_attribute: bg_attribute,
              tiles_low: tiles_low,
              tiles_high: tiles_high
            } =
              case i do
                8 ->
                  %{
                    bg_attribute: attribute_latch &&& 0xFFFF,
                    tiles_low: tiles_latch_low,
                    tiles_high: tiles_latch_high
                  }

                _ ->
                  %{
                    bg_attribute: bg_attribute,
                    tiles_low: tiles_low,
                    tiles_high: tiles_high
                  }
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

            List.update_at(tile_data, i, fn tile ->
              %{
                tile
                | pixel: Enum.at(palette, 0x3F1F &&& (bg_attribute ||| bg_index)),
                  index: bg_index &&& 0xFF
              }
            end)

            tiles_low = tiles_low <<< 1
            tiles_high = tiles_high <<< 1

            %{tiles_low: tiles_low, tiles_high: tiles_high}
          end
        )

        tiles_low = tiles_latch_low
        tiles_high = tiles_latch_high
        attributes = attribute_latch &&& 0xFFFF

        set_state(%{
          get_state()
          | attribute_latch: attribute_latch,
            attributes: attributes,
            tiles_low: tiles_low,
            tiles_high: tiles_high,
            tile_data: tile_data
        })
    end
  end

  def reverse_sprite(sprite) do
    sprite = (sprite &&& 0x55) <<< 1 ||| (sprite &&& 0xAA) >>> 1
    sprite = (sprite &&& 0x33) <<< 2 ||| (sprite &&& 0xCC) >>> 2
    (sprite &&& 0x0F) <<< 4 ||| (sprite &&& 0xF0) >>> 4
  end

  def fetch_sprites do
    %{
      cycle: cycle,
      sprites: sprites
    } = get_state()

    case cycle &&& 0x01C7 do
      0x0107 ->
        index = cycle >>> 3 &&& 0x07 &&& 0xFF
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

        attribute = sprite(oam_sprite, @sprite_palette) <<< 2 &&& 0xFFFF

        address = (0x3F10 ||| attribute) &&& 0xFFFF
        priority = sprite(oam_sprite, @priority)

        temp_tile_low = tile_low
        temp_tile_high = tile_high

        tile_data = List.duplicate(%{pixel: 0x00, index: 0x00}, 8)

        Enum.reduce(
          0..7,
          %{
            temp_tile_low: temp_tile_low,
            temp_tile_high: temp_tile_high
          },
          fn i,
             %{
               temp_tile_low: temp_tile_low,
               temp_tile_high: temp_tile_high
             } ->
            high = temp_tile_high &&& 0x80
            low = temp_tile_low &&& 0x80

            pindex = address ||| ((high >>> 6 ||| low >>> 7) &&& 0xFFFF)
            {:ok, pixel} = read(0x3F00 ||| (pindex &&& 0x001F))

            List.update_at(tile_data, i, fn tile ->
              %{tile | pixel: pixel, index: pindex &&& 0x0003}
            end)

            temp_tile_low = temp_tile_low <<< 1
            temp_tile_high = temp_tile_high <<< 1
            %{temp_tile_low: temp_tile_low, temp_tile_high: temp_tile_high}
          end
        )

        List.update_at(sprites, index, fn s ->
          %{
            s
            | tile_low: tile_low,
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
    controller(@background_pattern_address) ||| data <<< 4 ||| fetch_address(@fine_y_scroll)
  end

  def open_attribute(address) do
    0x23C0 ||| (address &&& 0x0C00) ||| (address >>> 4 &&& 0x0038) ||| (address >>> 2 &&& 0x0007)
  end

  def fetch_attribute(address) do
    {:ok, data} = read(address)

    %{
      registers: %{
        address: address_register
      }
    } = get_state()

    data >>> (((address_register &&& 0x02) ||| (address_register >>> 0x04 &&& 0x04)) &&& 0x03)
  end

  def sprite_address(sprite_data) do
    %{
      scanline: scanline
    } = get_state()

    comparitor = scanline - (sprite(sprite_data, @y_position) &&& 0xFFFF)

    comparitor =
      case sprite(sprite_data, @flip_vertically) do
        0 ->
          comparitor

        _ ->
          bxor(comparitor, 0x000F)
      end

    address =
      case controller(@sprite_size) do
        8 ->
          controller(@sprite_pattern_address) |||
            (sprite(sprite_data, @tile_number) &&& 0xFFFF) <<< 4

        16 ->
          (sprite(sprite_data, @tile_bank) &&& 0xFFFF) <<< 12 |||
            (sprite(sprite_data, @tile_number) &&& 0xFFFF) <<< 5 |||
            (comparitor &&& 0x08) <<< 1
      end

    address ||| (comparitor &&& 0x07)
  end

  def priority_multiplexer(bg_pixel, bg_index, sprite_pixel, sprite_index, sprite_priority) do
    %{
      show_background: show_background,
      show_sprites: show_sprites,
      palette: palette
    } = get_state()

    bg_index =
      case show_background do
        true -> bg_index
        false -> 0
      end

    sprite_index =
      case show_sprites do
        true -> sprite_index
        false -> 0
      end

    case bg_index do
      0 ->
        case sprite_index do
          0 -> Enum.at(palette, 0)
          _ -> sprite_pixel
        end

      _ ->
        case sprite_index do
          0 ->
            bg_pixel

          _ ->
            case sprite_priority do
              0 -> sprite_pixel
              _ -> bg_pixel
            end
        end
    end
  end

  def render_background do
    %{
      cycle: cycle,
      tile_data: tile_data,
      registers: %{
        scroll: scroll
      }
    } = get_state()

    show_background = mask?(@show_background)
    show_background_left = mask?(@show_background_left)

    cond do
      show_background && (show_background_left || cycle > 8) ->
        index = (cycle - 1 &&& 0x0007) + scroll
        %{pixel: bg_pixel, index: bg_index} = Enum.at(tile_data, index)
        {bg_pixel, bg_index}

      true ->
        {0x00, 0x00}
    end
  end

  def render_sprites do
    %{
      cycle: cycle
    } = get_state()

    show_background = mask?(@show_background)
    show_background_left = mask?(@show_background_left)

    render_sprites(show_background && (show_background_left || cycle > 8))
  end

  def render_sprites(false) do
    %{
      sprite_index: 0x00,
      sprite_pixel: 0x00,
      sprite_priority: 0x00,
      sprite_zero: false
    }
  end

  def render_sprites(true) do
    %{
      cycle: cycle,
      sprites: sprites
    } = get_state()

    cycle = cycle - 1

    Enum.find(sprites, fn %{
                            tile_data: tile_data,
                            x_position: x_position
                          } ->
      x = cycle - x_position

      case x do
        x when x < 8 ->
          %{index: index} = Enum.at(tile_data, x)
          x < 8 && index != 0x00

        _ ->
          false
      end
    end)
    |> case do
      nil ->
        render_sprites(false)

      %{
        tile_data: tile_data,
        priority: priority,
        zero: zero,
        x_position: x_position
      } ->
        %{index: index, pixel: pixel} = Enum.at(tile_data, cycle - x_position)

        %{
          sprite_index: index,
          sprite_pixel: pixel,
          sprite_priority: priority,
          zero: zero
        }
    end
  end

  def open_nt_byte do
    %{
      registers: %{
        address: address
      }
    } = get_state()

    set_state(%{get_state() | address_line: open_name(address)})
  end

  def fetch_nt_byte do
    %{
      address_line: address_line
    } = get_state()

    set_state(%{get_state() | pattern_address: fetch_name(address_line)})
  end

  def open_at_byte do
    %{
      registers: %{
        address: address
      }
    } = get_state()

    set_state(%{get_state() | address_line: open_attribute(address)})
  end

  def fetch_at_byte do
    %{
      address_line: address_line
    } = get_state()

    set_state(%{get_state() | attribute_next: fetch_name(address_line)})
  end

  def open_low_bg_tile_byte do
    %{
      pattern_address: pattern_address
    } = get_state()

    set_state(%{get_state() | address_line: pattern_address})
  end

  def fetch_low_bg_tile_byte do
    %{
      address_line: address_line
    } = get_state()

    {:ok, data} = read(address_line)
    set_state(%{get_state() | tiles_latch_low: data})
  end

  def open_high_bg_tile_byte do
    %{
      pattern_address: pattern_address
    } = get_state()

    set_state(%{get_state() | address_line: pattern_address &&& 0x0008})
  end

  def fetch_high_bg_tile_byte do
    %{
      address_line: address_line
    } = get_state()

    {:ok, data} = read(address_line)
    set_state(%{get_state() | tiles_latch_high: data})

    increment_x()

    %{cycle: cycle} = get_state()

    if cycle == 256 do
      increment_y()
    end
  end

  def set_hori_v do
    transfer_x()
  end

  def set_vert_v do
    %{scanline: scanline} = get_state()

    if scanline == 261 do
      transfer_y()
    end
  end

  @open_nt_byte_cycles [
    1,
    9,
    17,
    25,
    33,
    41,
    49,
    57,
    65,
    73,
    81,
    89,
    97,
    105,
    113,
    121,
    129,
    137,
    145,
    153,
    161,
    169,
    177,
    185,
    193,
    201,
    209,
    217,
    225,
    233,
    241,
    249,
    321,
    329,
    337,
    339
  ]
  @fetch_nt_byte_cycles [
    2,
    10,
    18,
    26,
    34,
    42,
    50,
    58,
    66,
    74,
    82,
    90,
    98,
    106,
    114,
    122,
    130,
    138,
    146,
    154,
    162,
    170,
    178,
    186,
    194,
    202,
    210,
    218,
    226,
    234,
    242,
    250,
    322,
    330,
    338,
    340
  ]
  @open_at_byte_cycles [
    3,
    11,
    19,
    27,
    35,
    43,
    51,
    59,
    67,
    75,
    83,
    91,
    99,
    107,
    115,
    123,
    131,
    139,
    147,
    155,
    163,
    171,
    179,
    187,
    195,
    203,
    211,
    219,
    227,
    235,
    243,
    251,
    323,
    331
  ]
  @fetch_at_byte_cycles [
    4,
    12,
    20,
    28,
    36,
    44,
    52,
    60,
    68,
    76,
    84,
    92,
    100,
    108,
    116,
    124,
    132,
    140,
    148,
    156,
    164,
    172,
    180,
    188,
    196,
    204,
    212,
    220,
    228,
    236,
    244,
    252,
    324,
    332
  ]
  @open_low_bg_tile_byte_cycles [
    5,
    13,
    21,
    29,
    37,
    45,
    53,
    61,
    69,
    77,
    85,
    93,
    101,
    109,
    117,
    125,
    133,
    141,
    149,
    157,
    165,
    173,
    181,
    189,
    197,
    205,
    213,
    221,
    229,
    237,
    245,
    253,
    325,
    333
  ]
  @fetch_low_bg_tile_byte_cycles [
    6,
    14,
    22,
    30,
    38,
    46,
    54,
    62,
    70,
    78,
    86,
    94,
    102,
    110,
    118,
    126,
    134,
    142,
    150,
    158,
    166,
    174,
    182,
    190,
    198,
    206,
    214,
    222,
    230,
    238,
    246,
    254,
    326,
    334
  ]
  @open_high_bg_tile_byte_cycles [
    7,
    15,
    23,
    31,
    39,
    47,
    55,
    63,
    71,
    79,
    87,
    95,
    103,
    111,
    119,
    127,
    135,
    143,
    151,
    159,
    167,
    175,
    183,
    191,
    199,
    207,
    215,
    223,
    231,
    239,
    247,
    255,
    327,
    335
  ]
  @fetch_high_bg_tile_byte_cycles [
    8,
    16,
    24,
    32,
    40,
    48,
    56,
    64,
    72,
    80,
    88,
    96,
    104,
    112,
    120,
    128,
    136,
    144,
    152,
    160,
    168,
    176,
    184,
    192,
    200,
    208,
    216,
    224,
    232,
    240,
    248,
    256,
    328,
    336
  ]
  @set_hori_v_cycles 257
  @set_vert_v_cycles [
    280,
    281,
    282,
    283,
    284,
    285,
    286,
    287,
    288,
    289,
    290,
    291,
    292,
    293,
    294,
    295,
    296,
    297,
    298,
    299,
    300,
    301,
    302,
    303,
    304
  ]

  def cycle_jump_table(cycle) when cycle in @open_nt_byte_cycles do
    open_nt_byte()
  end

  def cycle_jump_table(cycle) when cycle in @fetch_nt_byte_cycles do
    fetch_nt_byte()
  end

  def cycle_jump_table(cycle) when cycle in @open_at_byte_cycles do
    open_at_byte()
  end

  def cycle_jump_table(cycle) when cycle in @fetch_at_byte_cycles do
    fetch_at_byte()
  end

  def cycle_jump_table(cycle) when cycle in @open_low_bg_tile_byte_cycles do
    open_low_bg_tile_byte()
  end

  def cycle_jump_table(cycle) when cycle in @fetch_low_bg_tile_byte_cycles do
    fetch_low_bg_tile_byte()
  end

  def cycle_jump_table(cycle) when cycle in @open_high_bg_tile_byte_cycles do
    open_high_bg_tile_byte()
  end

  def cycle_jump_table(cycle) when cycle in @fetch_high_bg_tile_byte_cycles do
    fetch_high_bg_tile_byte()
  end

  def cycle_jump_table(@set_hori_v_cycles), do: set_hori_v()

  def cycle_jump_table(cycle) when cycle in @set_vert_v_cycles do
    set_vert_v()
  end

  def cycle_jump_table(_), do: :ok

  def render_visible_scanline do
    fetch_background()

    %{
      cycle: cycle
    } = get_state()

    cycle_jump_table(cycle)

    %{
      cycle: cycle,
      scanline: scanline,
      registers: %{status: status} = registers,
      colors: colors
    } = get_state()

    if cycle >= 1 && cycle <= 256 do
      {bg_pixel, bg_index} = render_background()

      %{
        sprite_pixel: sprite_pixel,
        sprite_index: sprite_index,
        sprite_priority: sprite_priority,
        sprite_zero: sprite_zero
      } = render_sprites()

      color =
        priority_multiplexer(bg_pixel, bg_index, sprite_pixel, sprite_index, sprite_priority)

      status =
        if scanline != 0 && sprite_zero && bg_index != 0 && sprite_index != 0 &&
             (cycle > 8 || (mask?(@show_background_left) && mask?(@show_sprites_left))) &&
             cycle < 256 && (mask?(@show_background) && mask?(@show_sprites)) do
          status ||| (@sprite_0_hit &&& 0xFF)
        else
          status
        end

      case scanline >= @first_visible_scanline && scanline <= @last_visible_scanline do
        true ->
          List.update_at(colors, (scanline <<< 8) + (cycle - 1), fn _ -> color end)
      end

      status =
        if OAM.sprite_evaluation(scanline, cycle, controller(@sprite_size)) do
          status ||| (@sprite_overflow &&& 0xFF)
        else
          status
        end

      registers = %{registers | status: status}
      set_state(%{get_state() | registers: registers, colors: colors})
    end

    fetch_sprites()
  end

  def execute do
    %{
      scanline: scanline,
      registers: %{status: status},
      pre_render_scanline: pre_render_scanline,
      frame: frame,
      cycle: cycle,
      num_scanlines: num_scanlines,
      colors: colors,
      region: region,
      interrupt: interrupt
    } = get_state()

    {return_cycle, return_status} =
      cond do
        (scanline >= @first_visible_scanline && scanline <= @last_visible_scanline) ||
            scanline == pre_render_scanline ->
          return_status =
            if cycle == 0 && scanline == pre_render_scanline do
              status &&& ~~~((@vblank_started ||| @sprite_0_hit ||| @sprite_overflow) &&& 0xFF)
            else
              status
            end

          return_cycle =
            case rendering?() do
              true ->
                render_visible_scanline()

                case region != :pal && (frame &&& 0x01) == 0x01 && scanline == pre_render_scanline &&
                       cycle == 339 do
                  true -> cycle + 1
                  false -> cycle
                end

              false ->
                cycle
            end

          {return_cycle, return_status}

        true ->
          return_status =
            case scanline == @start_nmi_scanline && cycle == 1 do
              true ->
                if status?(@vblank_started) && controller(@nmi_on_vblank) != 0 do
                  interrupt.()
                end

                status ||| (@vblank_started &&& 0xFF)
            end

          {cycle, return_status}
      end

    cycle = return_cycle + 1

    {frame, scanline, return_colors} =
      case cycle == @cycles_per_scanline do
        true ->
          scanline = scanline + 1

          case scanline == num_scanlines do
            true ->
              return_colors =
                case rendering?() do
                  true -> colors
                  false -> List.duplicate(0x00, @frame_size)
                end

              scanline = 0
              frame = frame + 1

              {frame, scanline, return_colors}

            false ->
              {frame, scanline, List.duplicate(0x00, @frame_size)}
          end

        _ ->
          {frame, scanline, List.duplicate(0x00, @frame_size)}
      end

    set_state(%{
      get_state()
      | cycle: cycle,
        scanline: scanline,
        frame: frame,
        status: return_status
    })

    return_colors
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
    start_memory()

    %{
      colors: List.duplicate(0x00, @frame_size),
      show_background: true,
      show_sprites: true,
      frame: 0x0000,
      scanline: 0x0000,
      cycle: 0x0000,
      registers: new_registers(),
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
      sprites:
        List.duplicate(
          %{
            tile_low: 0x00,
            tile_high: 0x00,
            sprite: 0x00000000,
            x_position: 0x00,
            address: 0x0000,
            priority: 0x00,
            zero: false,
            tile_data: List.duplicate(%{pixel: 0x00, index: 0x00}, 8)
          },
          8
        ),
      region: :pal,
      num_scanlines: 0x0000,
      pre_render_scanline: 0x0000,
      interrupt: fn -> :ok end
    }
  end

  def new_registers do
    %{
      controller: 0x00,
      mask: 0x00,
      status: 0x00,
      oam_address: 0x00,
      scroll: 0x00,
      address: 0x00,
      data: 0x00
    }
  end
end
