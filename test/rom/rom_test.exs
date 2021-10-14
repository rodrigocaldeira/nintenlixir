defmodule Nintenlixir.ROMTest do
  use ExUnit.Case

  alias Nintenlixir.ROM

  setup do
    start_supervised(ROM)
    :ok
  end

  test "ROM.load/1" do
    ROM.load(test_file())

    ROM.get_state()
    |> IO.inspect()
  end

  def test_file do
    Path.join(:code.priv_dir(:nintenlixir), 'nestest.nes')
  end
end
