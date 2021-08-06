defmodule Nintenlixir.CPUTest do
  use ExUnit.Case, async: true

  alias Nintenlixir.CPU

  setup do
    start_supervised(CPU)
    :ok
  end

  test "CPU.get_state/0 should return a brand new CPU state in it's creation" do
    assert %{
             decimal_mode: true,
             break_error: false,
             nmi: false,
             irq: false,
             rst: false
           } == CPU.get_state()
  end
end
