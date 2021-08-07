defmodule Nintenlixir.CPU do
  use GenServer
  use Bitwise

  # API

  alias Nintenlixir.Memory
  alias Nintenlixir.Registers
  alias Nintenlixir.ProcessorStatus

  def start_link(_) do
    GenServer.start_link(__MODULE__, new_cpu(), name: __MODULE__)
  end

  def get_state, do: GenServer.call(__MODULE__, :get_state)

  def reset do
    :ok = Memory.reset(memory_server_name())
    :ok = Registers.reset(registers_server_name())
    GenServer.call(__MODULE__, :reset)
  end

  def push(value), do: GenServer.call(__MODULE__, {:push, value})

  def push16(value) do
    :ok = push(value >>> 8)
    push(value &&& 0x00FF)
  end

  def pop, do: GenServer.call(__MODULE__, :pop)

  def pop16 do
    {:ok, low} = pop()
    {:ok, high} = pop()
    {:ok, high <<< 8 ||| low}
  end

  def irq, do: GenServer.call(__MODULE__, {:receive_interrupt, :irq})
  def nmi, do: GenServer.call(__MODULE__, {:receive_interrupt, :nmi})
  def rst, do: GenServer.call(__MODULE__, {:receive_interrupt, :rst})

  def interrupt do
    %{irq: irq, nmi: nmi, rst: rst} = state = GenServer.call(__MODULE__, :get_state)

    cycles =
      case [irq, nmi, rst] do
        [false, false, false] -> 0
        _ -> 7
      end

    %{processor_status: p} = Registers.get_registers(registers_server_name())

    if irq && (p &&& ProcessorStatus.InterruptDisable.value()) == 0 do
      %{
        program_counter: pc,
        processor_status: p
      } = Registers.get_registers(registers_server_name())

      :ok = push16(pc)

      :ok =
        push(
          (p ||| ProcessorStatus.Unused.value()) &&&
            ~~~ProcessorStatus.BreakCommand.value()
        )

      p = p ||| ProcessorStatus.InterruptDisable.value()

      {:ok, low} = Memory.read(memory_server_name(), 0xFFFE)
      {:ok, high} = Memory.read(memory_server_name(), 0xFFFF)

      pc = high <<< 8 ||| low

      registers = Registers.get_registers(registers_server_name())

      :ok =
        Registers.set_registers(registers_server_name(), %{
          registers
          | program_counter: pc,
            processor_status: p
        })

      :ok = GenServer.call(__MODULE__, {:set_state, %{state | irq: false}})
    end

    if nmi do
      %{
        program_counter: pc,
        processor_status: p
      } = Registers.get_registers(registers_server_name())

      :ok = push16(pc)

      :ok =
        push(
          (p ||| ProcessorStatus.Unused.value()) &&&
            ~~~ProcessorStatus.BreakCommand.value()
        )

      p = p ||| ProcessorStatus.InterruptDisable.value()

      {:ok, low} = Memory.read(memory_server_name(), 0xFFFA)
      {:ok, high} = Memory.read(memory_server_name(), 0xFFFB)

      pc = high <<< 8 ||| low

      registers = Registers.get_registers(registers_server_name())

      :ok =
        Registers.set_registers(registers_server_name(), %{
          registers
          | program_counter: pc,
            processor_status: p
        })

      :ok = GenServer.call(__MODULE__, {:set_state, %{state | nmi: false}})
    end

    if rst do
      :ok = GenServer.call(__MODULE__, :reset)
      :ok = GenServer.call(__MODULE__, {:set_state, %{state | rst: false}})
    end

    {:ok, cycles}
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

  def handle_call({:receive_interrupt, :irq}, _, state), do: {:reply, :ok, %{state | irq: true}}
  def handle_call({:receive_interrupt, :nmi}, _, state), do: {:reply, :ok, %{state | nmi: true}}
  def handle_call({:receive_interrupt, :rst}, _, state), do: {:reply, :ok, %{state | rst: true}}

  def handle_call({:set_state, new_state}, _, _), do: {:reply, :ok, new_state}

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
