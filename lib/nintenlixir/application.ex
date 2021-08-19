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
            Nintenlixir.Memory,
            {Nintenlixir.CPU.Registers, Nintenlixir.CPU.MOS6502.registers_server_name()}
          ]
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Nintenlixir.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
