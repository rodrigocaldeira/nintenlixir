defmodule Nintenlixir.PPU.RP2C02 do
  use GenServer

  alias Nintenlixir.PPU.Registers
  alias Nintenlixir.PPU.TileData

  def start_link(_) do
    GenServer.start_link(__MODULE__, new_ppu(), name: __MODULE__)
  end

  # Server

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  # Helpers

  defp new_ppu() do
  end
end
