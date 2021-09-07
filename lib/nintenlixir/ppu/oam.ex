defmodule Nintenlixir.PPU.OAM do
  use GenServer
  use Bitwise

  alias Nintenlixir.Memory

  @basic_memory_name :oam_basic_memory
  @buffer_name :oam_buffer

  # API

  def start_link(_) do
    GenServer.start_link(__MODULE__, new_oam(), name: __MODULE__)
  end

  def read(address) do
    Memory.read(@basic_memory_name, address)
  end

  def read_buffer(address) do
    Memory.read(@buffer_name, address)
  end

  def write(address, data) do
    Memory.write(@basic_memory_name, address, data)
  end

  def write_buffer(address, data) do
    Memory.write(@buffer_name, address, data)
  end

  def get_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  def set_state(state) do
    GenServer.call(__MODULE__, {:set_state, state})
  end

  def increment_address(mask) do
    %{address: address} = get_state()
    set_state(%{get_state() | address: address + 1 &&& mask})
  end

  def fetch_address do
    %{address: address} = get_state()

    if address < 0x0100 do
      {:ok, latch} = read(address)
      set_state(%{get_state() | latch: latch})
    end

    :ok
  end

  def clear_buffer do
    %{address: address, latch: latch} = get_state()
    write_buffer(address, latch)
    increment_address(0x001F)
  end

  def copy_y_position(scanline, size) do
    %{
      latch: latch,
      index: index,
      address: address,
      write_cycle: write_cycle
    } = get_state()

    if (scanline - latch &&& 0xFFFF) < size do
      write_buffer(index, latch)
      :ok = increment_address(0x00FF)
      set_state(%{get_state() | write_cycle: :copy_index})
    else
      address = address + 4

      write_cycle =
        if address >= 0x0100 do
          :fail_copy_y_position
        else
          write_cycle
        end

      set_state(%{get_state() | address: address, write_cycle: write_cycle})
    end
  end

  def copy_index do
    %{index: index, latch: latch} = get_state()
    write_buffer(index + 1, latch)
    :ok = increment_address(0x00FF)
    set_state(%{get_state() | write_cycle: :copy_attributes})
  end

  def copy_attributes do
    %{index: index, latch: latch} = get_state()
    write_buffer(index + 2, latch)
    :ok = increment_address(0x00FF)
    set_state(%{get_state() | write_cycle: :copy_x_position})
  end

  def copy_x_position do
    %{
      index: index,
      latch: latch
    } = get_state()

    write_buffer(index + 3, latch)

    :ok = increment_address(0x00FF)

    :ok = set_state(%{get_state() | sprite_zero_in_buffer: index == 0x0000, index: index + 4})

    handle_copy_x_position(get_state())
  end

  defp handle_copy_x_position(%{address: address}) when address >= 0x0100 do
    set_state(%{get_state() | write_cycle: :fail_copy_y_position})
  end

  defp handle_copy_x_position(%{index: index}) when index < 32 do
    set_state(%{get_state() | write_cycle: :copy_y_position})
  end

  defp handle_copy_x_position(_) do
    Memory.disable_writes(@buffer_name)
    %{address: address} = get_state()
    address = address &&& 0x00FC
    set_state(%{get_state() | address: address, write_cycle: :evaluate_y_position})
  end

  def evaluate_y_position(scanline, size) do
    %{
      address: address,
      latch: latch
    } = get_state()

    if (scanline - latch &&& 0xFFFF) < size do
      :ok = increment_address(0x00FF)
      :ok = set_state(%{get_state() | write_cycle: :evaluate_index})
      :sprite_overflow
    else
      address = (address + 4 &&& 0x00FC) + (address + 1 &&& 0x0003)

      if address <= 0x0005 do
        set_state(%{get_state() | address: address &&& 0x00FC, write_cycle: :fail_copy_y_position})
      else
        set_state(%{get_state() | address: address})
      end
    end
  end

  def evaluate_index do
    :ok = increment_address(0x00FF)
    set_state(%{get_state() | write_cycle: :evaluate_attributes})
  end

  def evaluate_attributes do
    :ok = increment_address(0x00FF)
    set_state(%{get_state() | write_cycle: :evaluate_x_position})
  end

  def evaluate_x_position do
    :ok = increment_address(0x00FF)
    %{address: address} = get_state()

    if (address &&& 0x0003) == 0x0003 do
      :ok = increment_address(0x00FF)
    end

    %{address: address} = get_state()

    set_state(%{get_state() | address: address &&& 0x00FC, write_cycle: :fail_copy_y_position})
  end

  def fail_copy_y_position do
    %{address: address} = get_state()
    set_state(%{get_state() | address: address + 4 &&& 0x00FF})
  end

  def sprite(index) do
    address = index <<< 2

    {:ok, data_1} = read_buffer(address)
    {:ok, data_2} = read_buffer(address + 1)
    {:ok, data_3} = read_buffer(address + 2)
    {:ok, data_4} = read_buffer(address + 3)

    data_1 = data_1 <<< 24
    data_2 = data_2 <<< 16
    data_3 = data_3 <<< 8
    data_4 = data_4

    {:ok, data_1 ||| data_2 ||| data_3 ||| data_4}
  end

  def sprite_evaluation(261, _, _), do: :ok

  def sprite_evaluation(_, 1, _) do
    set_state(%{
      get_state()
      | address: 0,
        latch: 0xFF,
        index: 0,
        sprite_zero_in_buffer: false,
        write_cycle: :clear_buffer
    })

    Memory.disable_reads(@basic_memory_name)
    Memory.enable_writes(@buffer_name)
    fetch_address()
  end

  def sprite_evaluation(_, 65, _) do
    set_state(%{
      get_state()
      | address: 0,
        latch: 0xFF,
        index: 0,
        write_cycle: :copy_y_position
    })

    Memory.enable_reads(@basic_memory_name)
    fetch_address()
  end

  def sprite_evaluation(scanline, cycle, size) when rem(cycle, 2) == 0 do
    %{write_cycle: write_cycle} = get_state()
    exec_cycle_function(write_cycle, scanline, size)
  end

  def sprite_evaluation(_, _, _) do
    fetch_address()
  end

  def exec_cycle_function(:clear_buffer, _, _), do: clear_buffer()

  def exec_cycle_function(:copy_y_position, scanline, size) do
    copy_y_position(scanline, size)
  end

  def exec_cycle_function(:copy_index, _, _), do: copy_index()
  def exec_cycle_function(:copy_attributes, _, _), do: copy_attributes()
  def exec_cycle_function(:copy_x_position, _, _), do: copy_x_position()

  def exec_cycle_function(:evaluate_y_position, scanline, size) do
    evaluate_y_position(scanline, size)
  end

  def exec_cycle_function(:evaluate_index, _, _), do: evaluate_index()
  def exec_cycle_function(:evaluate_attributes, _, _), do: evaluate_attributes()
  def exec_cycle_function(:evaluate_x_position, _, _), do: evaluate_x_position()
  def exec_cycle_function(:fail_copy_y_position, _, _), do: fail_copy_y_position()

  # Server

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_state, _, state), do: {:reply, state, state}

  def handle_call({:set_state, state}, _, _), do: {:reply, :ok, state}

  # Helpers

  defp new_oam() do
    %{
      address: 0x0000,
      latch: 0x00,
      sprite_zero_in_buffer: false,
      index: 0x0000,
      write_cycle: :fail_copy_y_position
    }
  end
end
