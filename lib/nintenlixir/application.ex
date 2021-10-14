defmodule Nintenlixir.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      case Mix.env() do
        :test ->
          []

        _ ->
          [
            Nintenlixir.CPU.MOS6502,
            Supervisor.child_spec(
              {Nintenlixir.Memory, Nintenlixir.CPU.MOS6502.memory_server_name()},
              id: Nintenlixir.CPU.MOS6502.memory_server_name()
            ),
            Supervisor.child_spec(
              {Nintenlixir.Memory, Nintenlixir.PPU.RP2C02.memory_server_name()},
              id: Nintenlixir.PPU.RP2C02.memory_server_name()
            ),
            Supervisor.child_spec({Nintenlixir.Memory, :oam_basic_memory}, id: :oam_basic_memory),
            Supervisor.child_spec({Nintenlixir.Memory, :oam_buffer}, id: :oam_buffer),
            Nintenlixir.PPU.OAM,
            Nintenlixir.PPU.NameTableMapper,
            Nintenlixir.PPU.RP2C02,
            Nintenlixir.ROM
          ]
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Nintenlixir.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
