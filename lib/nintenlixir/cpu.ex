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

    %{processor_status: p} = get_registers()

    if irq && (p &&& ProcessorStatus.InterruptDisable.value()) == 0 do
      %{
        program_counter: pc,
        processor_status: p
      } = get_registers()

      :ok = push16(pc)

      :ok =
        push(
          (p ||| ProcessorStatus.Unused.value()) &&&
            ~~~ProcessorStatus.BreakCommand.value()
        )

      p = p ||| ProcessorStatus.InterruptDisable.value()

      {:ok, low} = read_memory(0xFFFE)
      {:ok, high} = read_memory(0xFFFF)

      pc = high <<< 8 ||| low

      registers = get_registers()

      :ok =
        set_registers(%{
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
      } = get_registers()

      :ok = push16(pc)

      :ok =
        push(
          (p ||| ProcessorStatus.Unused.value()) &&&
            ~~~ProcessorStatus.BreakCommand.value()
        )

      p = p ||| ProcessorStatus.InterruptDisable.value()

      {:ok, low} = read_memory(0xFFFA)
      {:ok, high} = read_memory(0xFFFB)

      pc = high <<< 8 ||| low

      registers = get_registers()

      :ok =
        set_registers(%{
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

  def set_Z_flag(0x00) do
    %{processor_status: p} = registers = get_registers()

    :ok =
      set_registers(%{
        registers
        | processor_status: p ||| ProcessorStatus.ZeroFlag.value()
      })

    {:ok, 0x00}
  end

  def set_Z_flag(value) do
    %{processor_status: p} = registers = get_registers()

    :ok =
      set_registers(%{
        registers
        | processor_status: p &&& ~~~ProcessorStatus.ZeroFlag.value()
      })

    {:ok, value}
  end

  def set_N_flag(value) do
    %{processor_status: p} = registers = get_registers()

    :ok =
      set_registers(%{
        registers
        | processor_status:
            (p &&& ~~~ProcessorStatus.NegativeFlag.value()) |||
              (value &&& ProcessorStatus.NegativeFlag.value())
      })

    {:ok, value}
  end

  def set_C_flag_addition(value) do
    %{processor_status: p} = registers = get_registers()

    :ok =
      set_registers(%{
        registers
        | processor_status:
            (p &&& ~~~ProcessorStatus.CarryFlag.value()) |||
              (value >>> 8 &&& ProcessorStatus.CarryFlag.value())
      })

    {:ok, value}
  end

  def set_V_flag_addition(term1, term2, result) do
    %{processor_status: p} = registers = get_registers()

    :ok =
      set_registers(%{
        registers
        | processor_status:
            (p &&& ~~~ProcessorStatus.OverflowFlag.value()) |||
              (~~~(bxor(term1, term2) &&& bxor(term1, result)) &&&
                 ProcessorStatus.NegativeFlag.value()) >>> 1
      })

    {:ok, result}
  end

  def immediate_address do
    %{program_counter: pc} = registers = get_registers()
    :ok = set_registers(%{registers | program_counter: pc + 1})
    {:ok, pc}
  end

  def zero_page_address do
    %{program_counter: pc} = registers = get_registers()
    {:ok, result} = read_memory(pc)
    :ok = set_registers(%{registers | program_counter: pc + 1})
    {:ok, result}
  end

  def relative_address do
    %{program_counter: pc} = registers = get_registers()
    {:ok, value} = read_memory(pc)
    pc = pc + 1
    :ok = set_registers(%{registers | program_counter: pc})

    offset =
      if value > 0x7F do
        -(0x0100 - value)
      else
        value
      end

    {:ok, pc + offset &&& 0xFFFF}
  end

  def absolute_address do
    %{program_counter: pc} = registers = get_registers()
    {:ok, low} = read_memory(pc)
    {:ok, high} = read_memory(pc + 1)
    :ok = set_registers(%{registers | program_counter: pc + 2})

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
    {:ok, low} = read_memory(0xFFFC)
    {:ok, high} = read_memory(0xFFFD)

    pc = high <<< 8 ||| low

    registers = get_registers()

    :ok = set_registers(%{registers | program_counter: pc})

    {:reply, :ok, state}
  end

  def handle_call({:push, value}, _, state) do
    %{stack_pointer: sp} = registers = get_registers()

    :ok = write_memory(0x0100 ||| sp, value)

    :ok = set_registers(%{registers | stack_pointer: sp - 1})

    {:reply, :ok, state}
  end

  def handle_call(:pop, _, state) do
    %{stack_pointer: sp} = registers = get_registers()

    sp = sp + 1

    {:ok, value} = read_memory(0x0100 ||| sp)

    :ok = set_registers(%{registers | stack_pointer: sp})

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

  defp get_registers, do: Registers.get_registers(registers_server_name())
  defp set_registers(registers), do: Registers.set_registers(registers_server_name(), registers)

  defp read_memory(address), do: Memory.read(memory_server_name(), address)
  defp write_memory(address, value), do: Memory.write(memory_server_name(), address, value)
end
