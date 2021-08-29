defmodule Nintenlixir.PPU.Sprite do
  defstruct tile_low: 0x00,
            tile_high: 0x00,
            sprite: 0x00,
            x_position: 0x00,
            address: 0x00,
            priority: 0x00,
            zero: false,
            tile_data: nil
end
