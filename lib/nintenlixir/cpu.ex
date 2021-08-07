defmodule Nintenlixir.CPU do
  use GenServer
  use Bitwise

  # API

  alias Nintenlixir.Memory
  alias Nintenlixir.Registers

  def start_link(_) do
    GenServer.start_link(__MODULE__, new_cpu(), name: __MODULE__)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def reset do
    :ok = Memory.reset(memory_server_name())
    :ok = Registers.reset(registers_server_name())
    GenServer.call(__MODULE__, :reset)
  end

  def push(value) do
    GenServer.call(__MODULE__, {:push, value})
  end

  def push16(value) do
    :ok = push(value >>> 8)
    push(value &&& 0x00FF)
  end

  def pop do
    GenServer.call(__MODULE__, :pop)
  end

  def pop16 do
    {:ok, low} = pop()
    {:ok, high} = pop()

    {:ok, high <<< 8 ||| low}
  end

  # Server

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_state, _, state) do
    {:reply, state, state}
  end

  def handle_call(:reset, _, state) do
    {:ok, low} = Memory.read(memory_server_name(), 0xFFFC)
    {:ok, high} = Memory.read(memory_server_name(), 0xFFFD)

    pc = high <<< 8 ||| low

    registers = Registers.get_registers(registers_server_name())

    :ok = Registers.set_registers(registers_server_name(), %{registers | program_counter: pc})

    {:reply, :ok, state}
  end

  def handle_call({:push, value}, _, state) do
    %{stack_pointer: sp} = registers = Registers.get_registers(registers_server_name())

    :ok = Memory.write(memory_server_name(), 0x0100 ||| sp, value)

    :ok = Registers.set_registers(registers_server_name(), %{registers | stack_pointer: sp - 1})

    {:reply, :ok, state}
  end

  def handle_call(:pop, _, state) do
    %{stack_pointer: sp} = registers = Registers.get_registers(registers_server_name())

    sp = sp + 1

    {:ok, value} = Memory.read(memory_server_name(), 0x0100 ||| sp)

    :ok = Registers.set_registers(registers_server_name(), %{registers | stack_pointer: sp})

    {:reply, {:ok, value}, state}
  end

  # Private helpers

  defp new_cpu(),
    do: %{
      decimal_mode: true,
      break_error: false,
      nmi: false,
      irq: false,
      rst: false
    }

  def memory_server_name, do: :memory_cpu
  def registers_server_name, do: :registers_cpu
end
