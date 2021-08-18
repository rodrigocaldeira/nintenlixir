defmodule Nintenlixir.MOS6502 do
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

  def set_ZN_flags(value) do
    {:ok, ^value} = set_Z_flag(value)
    {:ok, ^value} = set_N_flag(value)
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

  def zero_page_address(register) when is_atom(register) and register in [:x, :y] do
    {:ok, value} = zero_page_address()
    registers = get_registers()
    register_value = Map.get(registers, register)
    {:ok, register_value + value}
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

  def absolute_address(register) when is_atom(register) and register in [:x, :y] do
    {:ok, value} = absolute_address()
    register_value = Map.get(get_registers(), register)
    handle_indexed_address(value, register_value)
  end

  def indirect_address do
    %{program_counter: pc} = registers = get_registers()
    {:ok, low} = read_memory(pc)
    {:ok, high} = read_memory(pc + 1)
    :ok = set_registers(%{registers | program_counter: pc + 2})

    address_high = high <<< 8 ||| low + 1
    address_low = high <<< 8 ||| low

    {:ok, low} = read_memory(address_low)
    {:ok, high} = read_memory(address_high)

    {:ok, high <<< 8 ||| low}
  end

  def indirect_address(:x) do
    %{program_counter: pc, x: x} = registers = get_registers()
    address = pc + x
    :ok = set_registers(%{registers | program_counter: pc + 1})

    {:ok, low} = read_memory(address)
    {:ok, high} = read_memory(address + 1 &&& 0x00FF)

    {:ok, high <<< 8 ||| low}
  end

  def indirect_address(:y) do
    %{program_counter: pc, y: y} = registers = get_registers()
    :ok = set_registers(%{registers | program_counter: pc + 1})

    {:ok, low} = read_memory(pc)
    {:ok, high} = read_memory(pc + 1 &&& 0x00FF)

    value = high <<< 8 ||| low

    handle_indexed_address(value, y)
  end

  def load(address, register) do
    {:ok, value} = read_memory(address)
    {:ok, result} = set_ZN_flags(value)
    registers = get_registers() |> Map.put(register, result)
    :ok = set_registers(registers)
    {:ok, result}
  end

  def lda(address) do
    {:ok, _} = load(address, :accumulator)
    :ok
  end

  def lax(address) do
    registers = get_registers()
    {:ok, x} = read_memory(address)
    set_registers(%{registers | x: x})
    {:ok, _} = load(address, :accumulator)
    :ok
  end

  def ldx(address) do
    {:ok, _} = load(address, :x)
    :ok
  end

  def ldy(address) do
    {:ok, _} = load(address, :y)
    :ok
  end

  def sax(address) do
    %{accumulator: a, x: x} = get_registers()
    write_memory(address, a &&& x)
  end

  def sta(address) do
    %{accumulator: a} = get_registers()
    write_memory(address, a)
  end

  def stx(address) do
    %{x: x} = get_registers()
    write_memory(address, x)
  end

  def sty(address) do
    %{y: y} = get_registers()
    write_memory(address, y)
  end

  def transfer(from, to) do
    registers = get_registers()
    value_from = Map.get(registers, from)
    {:ok, ^value_from} = set_ZN_flags(value_from)

    registers
    |> Map.put(to, value_from)
    |> set_registers()
  end

  def tax, do: transfer(:accumulator, :x)
  def tay, do: transfer(:accumulator, :y)
  def txa, do: transfer(:x, :accumulator)
  def tya, do: transfer(:y, :accumulator)
  def tsx, do: transfer(:stack_pointer, :x)

  def txs do
    %{x: x} = registers = get_registers()
    set_registers(%{registers | stack_pointer: x})
  end

  def pha do
    %{accumulator: a} = get_registers()
    push(a)
  end

  def php do
    %{processor_status: p} = get_registers()
    push(p ||| ProcessorStatus.BreakCommand.value() ||| ProcessorStatus.Unused.value())
  end

  def pla do
    {:ok, value} = pop()
    {:ok, ^value} = set_ZN_flags(value)
    set_registers(%{get_registers() | accumulator: value})
  end

  def plp do
    {:ok, value} = pop()
    p = value &&& ~~~(ProcessorStatus.BreakCommand.value() ||| ProcessorStatus.Unused.value())
    set_registers(%{get_registers() | processor_status: p})
  end

  def and_op(address) do
    {:ok, value} = read_memory(address)
    %{accumulator: a} = registers = get_registers()
    {:ok, result} = set_ZN_flags(a &&& value)
    set_registers(%{registers | accumulator: result})
  end

  def xor_op(address) do
    {:ok, value} = read_memory(address)
    %{accumulator: a} = registers = get_registers()
    {:ok, result} = set_ZN_flags(bxor(a, value))
    set_registers(%{registers | accumulator: result})
  end

  def or_op(address) do
    {:ok, value} = read_memory(address)
    %{accumulator: a} = registers = get_registers()
    {:ok, result} = set_ZN_flags(a ||| value)
    set_registers(%{registers | accumulator: result})
  end

  def bit(address) do
    {:ok, value} = read_memory(address)
    %{accumulator: a, processor_status: p} = registers = get_registers()
    {:ok, _} = set_Z_flag(value &&& a)

    p =
      (p &&& ~~~(ProcessorStatus.NegativeFlag.value() ||| ProcessorStatus.OverflowFlag.value())) |||
        (value &&& (ProcessorStatus.NegativeFlag.value() ||| ProcessorStatus.OverflowFlag.value()))

    set_registers(%{registers | processor_status: p})
  end

  def disable_decimal_mode do
    GenServer.call(__MODULE__, {:set_state, %{get_state() | decimal_mode: false}})
  end

  def addition(value) do
    %{accumulator: a, processor_status: p} = registers = get_registers()
    %{decimal_mode: decimal_mode} = get_state()

    if !decimal_mode || (p &&& ProcessorStatus.DecimalMode.value()) == 0 do
      {:ok, result} = set_C_flag_addition(a + value + (p &&& ProcessorStatus.CarryFlag.value()))
      {:ok, ^result} = set_V_flag_addition(a, value, result)
      {:ok, ^result} = set_ZN_flags(result)
      set_registers(%{registers | accumulator: result})
    else
      low = (a &&& 0x000F) + (value &&& 0x000F) + (p &&& ProcessorStatus.CarryFlag.value())
      high = (a &&& 0x00F0) + (value &&& 0x00F0)

      low =
        if low >= 0x000A do
          low - 0x000A
        else
          low
        end

      high =
        if low >= 0x000A do
          high + 0x0010
        else
          high
        end

      high =
        if high >= 0x00A0 do
          high - 0x00A0
        else
          high
        end

      {:ok, result} = set_C_flag_addition(high ||| (low &&& 0x000F))
      {:ok, ^result} = set_V_flag_addition(a, value, result)
      {:ok, ^result} = set_ZN_flags(result)
      set_registers(%{registers | accumulator: result})
    end
  end

  def adc(address) do
    {:ok, value} = read_memory(address)
    addition(value)
  end

  def sbc(address) do
    {:ok, value} = read_memory(address)

    %{processor_status: p} = get_registers()
    %{decimal_mode: decimal_mode} = get_state()

    value =
      if !decimal_mode || (p &&& ProcessorStatus.DecimalMode.value()) == 0 do
        bxor(value, 0xFF)
      else
        0x99 - value
      end

    addition(value)
  end

  def compare(value1, value2) do
    value = bxor(value1, 0xFF) + 1
    {:ok, result} = set_C_flag_addition(value2 + value)
    {:ok, ^result} = set_ZN_flags(result)
    :ok
  end

  def cmp(address) do
    {:ok, value} = read_memory(address)
    %{accumulator: a} = get_registers()
    compare(value, a)
  end

  def cpx(address) do
    {:ok, value} = read_memory(address)
    %{x: x} = get_registers()
    compare(value, x)
  end

  def cpy(address) do
    {:ok, value} = read_memory(address)
    %{y: y} = get_registers()
    compare(value, y)
  end

  def inc(ref), do: unary_op(ref, &Kernel.+/2)

  def dec(ref), do: unary_op(ref, &Kernel.-/2)

  defp unary_op(register, f) when is_atom(register) do
    registers = get_registers()
    value = f.(Map.get(registers, register), 1)
    set_ZN_flags(value)
    set_registers(registers |> Map.put(register, value))
  end

  defp unary_op(address, f) do
    {:ok, value} = read_memory(address)
    value = f.(value, 1)
    set_ZN_flags(value)
    write_memory(address, value)
  end

  def shift(:left, value, ref) do
    value = value <<< 1
    c = (value &&& ProcessorStatus.NegativeFlag.value()) >>> 7
    :ok = update_shifted_value(value, c)
    store(value, ref)
  end

  def shift(:right, value, ref) do
    value = value >>> 1
    c = value &&& ProcessorStatus.CarryFlag.value()
    :ok = update_shifted_value(value, c)
    store(value, ref)
  end

  def rotate(:left, value, ref) do
    %{processor_status: p} = get_registers()

    value =
      (value <<< 1 &&& ~~~ProcessorStatus.CarryFlag.value()) |||
        (p &&& ProcessorStatus.CarryFlag.value())

    c = (value &&& ProcessorStatus.NegativeFlag.value()) >>> 7
    :ok = update_shifted_value(value, c)
    store(value, ref)
  end

  def rotate(:right, value, ref) do
    %{processor_status: p} = get_registers()

    value =
      (value >>> 1 &&& ~~~ProcessorStatus.NegativeFlag.value()) |||
        (p &&& ProcessorStatus.CarryFlag.value()) <<< 7

    c = value &&& ProcessorStatus.CarryFlag.value()
    :ok = update_shifted_value(value, c)
    store(value, ref)
  end

  defp store(value, ref) when is_atom(ref),
    do: set_registers(get_registers() |> Map.put(ref, value))

  defp store(value, ref), do: write_memory(ref, value)

  defp update_shifted_value(value, carry) do
    %{processor_status: p} = registers = get_registers()
    p = p &&& ~~~ProcessorStatus.CarryFlag.value()
    p = p ||| carry
    set_registers(%{registers | processor_status: p})
    {:ok, ^value} = set_ZN_flags(value)
    :ok
  end

  def jmp(address), do: set_registers(%{get_registers() | program_counter: address})

  def jsr(address) do
    %{program_counter: pc} = get_registers()
    value = pc - 1
    :ok = push16(value)
    set_registers(%{get_registers() | program_counter: address})
  end

  def rts do
    {:ok, value} = pop16()
    set_registers(%{get_registers() | program_counter: value + 1})
  end

  def branch(address, f) do
    if f.() do
      %{program_counter: pc} = get_registers()
      set_registers(%{get_registers() | program_counter: address})

      if !Memory.same_page?(pc, address) do
        {:ok, [:branched, :page_cross]}
      else
        {:ok, [:branched, :same_page]}
      end
    else
      {:ok, []}
    end
  end

  def bcc(address) do
    f = fn ->
      %{processor_status: p} = get_registers()
      (p &&& ProcessorStatus.CarryFlag.value()) == 0
    end

    branch(address, f)
  end

  def bcs(address) do
    f = fn ->
      %{processor_status: p} = get_registers()
      (p &&& ProcessorStatus.CarryFlag.value()) != 0
    end

    branch(address, f)
  end

  def beq(address) do
    f = fn ->
      %{processor_status: p} = get_registers()
      (p &&& ProcessorStatus.ZeroFlag.value()) != 0
    end

    branch(address, f)
  end

  def bmi(address) do
    f = fn ->
      %{processor_status: p} = get_registers()
      (p &&& ProcessorStatus.NegativeFlag.value()) != 0
    end

    branch(address, f)
  end

  def bne(address) do
    f = fn ->
      %{processor_status: p} = get_registers()
      (p &&& ProcessorStatus.ZeroFlag.value()) == 0
    end

    branch(address, f)
  end

  def bpl(address) do
    f = fn ->
      %{processor_status: p} = get_registers()
      (p &&& ProcessorStatus.NegativeFlag.value()) == 0
    end

    branch(address, f)
  end

  def bvc(address) do
    f = fn ->
      %{processor_status: p} = get_registers()
      (p &&& ProcessorStatus.OverflowFlag.value()) == 0
    end

    branch(address, f)
  end

  def bvs(address) do
    f = fn ->
      %{processor_status: p} = get_registers()
      (p &&& ProcessorStatus.OverflowFlag.value()) != 0
    end

    branch(address, f)
  end

  def clc, do: clear_processor_status_flag(ProcessorStatus.CarryFlag.value())
  def cld, do: clear_processor_status_flag(ProcessorStatus.DecimalMode.value())
  def cli, do: clear_processor_status_flag(ProcessorStatus.InterruptDisable.value())
  def clv, do: clear_processor_status_flag(ProcessorStatus.OverflowFlag.value())

  defp clear_processor_status_flag(flag) do
    %{processor_status: p} = get_registers()
    p = p &&& ~~~flag
    set_registers(%{get_registers() | processor_status: p})
  end

  def sec, do: set_processor_status_flag(ProcessorStatus.CarryFlag.value())
  def sed, do: set_processor_status_flag(ProcessorStatus.DecimalMode.value())
  def sei, do: set_processor_status_flag(ProcessorStatus.InterruptDisable.value())

  defp set_processor_status_flag(flag) do
    %{processor_status: p} = get_registers()
    p = p ||| flag
    set_registers(%{get_registers() | processor_status: p})
  end

  def brk do
    %{program_counter: pc, processor_status: p} = get_registers()
    pc = pc + 1
    push16(pc)
    push(p ||| ProcessorStatus.BreakCommand.value() ||| ProcessorStatus.Unused.value())

    p = p ||| ProcessorStatus.InterruptDisable.value()

    {:ok, low} = read_memory(0xFFFE)
    {:ok, high} = read_memory(0xFFFF)

    pc = high <<< 8 ||| low
    set_registers(%{get_registers() | program_counter: pc, processor_status: p})
  end

  def noop, do: :ok
  def noop(_), do: :ok

  def asl do
    %{accumulator: a} = get_registers()
    shift(:left, a, :accumulator)
  end

  def asl(address) do
    {:ok, value} = read_memory(address)
    shift(:left, value, address)
  end

  def lsr do
    %{accumulator: a} = get_registers()
    shift(:right, a, :accumulator)
  end

  def lsr(address) do
    {:ok, value} = read_memory(address)
    shift(:right, value, address)
  end

  def rol do
    %{accumulator: a} = get_registers()
    rotate(:left, a, :accumulator)
  end

  def rol(address) do
    {:ok, value} = read_memory(address)
    rotate(:left, value, address)
  end

  def ror do
    %{accumulator: a} = get_registers()
    rotate(:right, a, :accumulator)
  end

  def ror(address) do
    {:ok, value} = read_memory(address)
    rotate(:right, value, address)
  end

  def anc(address) do
    :ok = and_op(address)
    %{processor_status: p} = get_registers()
    p = (p &&& ~~~ProcessorStatus.CarryFlag.value()) ||| p >>> 7
    set_registers(%{get_registers() | processor_status: p})
  end

  def alr(address) do
    :ok = and_op(address)
    %{accumulator: a} = get_registers()
    shift(:right, a, :accumulator)
  end

  def arr(address) do
    :ok = and_op(address)
    %{accumulator: a} = get_registers()
    rotate(:right, a, :accumulator)
  end

  def shy(_), do: :ok
  def shx(_), do: :ok

  def axs(address) do
    {:ok, value} = read_memory(address)
    %{accumulator: a, x: x} = get_registers()
    x = x &&& a
    :ok = compare(value, x)
    x = x - value
    set_registers(%{get_registers() | x: x})
  end

  def rti do
    {:ok, p} = pop()
    p = p &&& ~~~(ProcessorStatus.BreakCommand.value() ||| ProcessorStatus.Unused.value())
    {:ok, pc} = pop16()
    set_registers(%{get_registers() | program_counter: pc, processor_status: p})
  end

  def dcp(address) do
    :ok = dec(address)
    cmp(address)
  end

  def isb(address) do
    :ok = inc(address)
    sbc(address)
  end

  def slo(address) do
    {:ok, value} = read_memory(address)
    :ok = shift(:left, value, address)
    %{accumulator: a} = get_registers()
    a = a ||| value
    {:ok, ^a} = set_ZN_flags(a)
    set_registers(%{get_registers() | accumulator: a})
  end

  def rla(address) do
    {:ok, value} = read_memory(address)
    rotate(:left, value, address)
    and_op(address)
  end

  def sre(address) do
    {:ok, value} = read_memory(address)
    :ok = rotate(:right, value, address)
    xor_op(address)
  end

  def rra(address) do
    {:ok, value} = read_memory(address)
    :ok = rotate(:right, value, address)
    adc(address)
  end

  def control_address(opcode) do
    if (opcode &&& 0x10) == 0x00 do
      case opcode >>> 2 &&& 0x03 do
        0x00 ->
          immediate_address()

        0x01 ->
          zero_page_address()

        0x02 ->
          {:ok, 0x00, :same_page}

        0x03 ->
          absolute_address()
      end
    else
      case opcode >>> 2 &&& 0x03 do
        0x00 ->
          relative_address()

        0x01 ->
          zero_page_address(:x)

        0x02 ->
          {:ok, 0x00, :same_page}

        0x03 ->
          absolute_address(:x)
      end
    end
    |> case do
      {:ok, address} ->
        {:ok, address, :same_page}

      result ->
        result
    end
  end

  def alu_address(opcode) do
    if (opcode &&& 0x10) == 0x00 do
      case opcode >>> 2 &&& 0x03 do
        0x00 ->
          indirect_address(:x)

        0x01 ->
          zero_page_address()

        0x02 ->
          immediate_address()

        0x03 ->
          absolute_address()
      end
    else
      case opcode >>> 2 &&& 0x03 do
        0x00 ->
          indirect_address(:x)

        0x01 ->
          zero_page_address(:x)

        0x02 ->
          absolute_address(:y)

        0x03 ->
          absolute_address(:x)
      end
    end
    |> case do
      {:ok, address} ->
        {:ok, address, :same_page}

      result ->
        result
    end
  end

  def rmw_address(opcode) do
    if (opcode &&& 0x10) == 0x00 do
      case opcode >>> 2 &&& 0x03 do
        0x00 ->
          immediate_address()

        0x01 ->
          zero_page_address()

        0x02 ->
          {:ok, 0x00, :same_page}

        0x03 ->
          absolute_address()
      end
    else
      case opcode >>> 2 &&& 0x03 do
        0x00 ->
          {:ok, 0x00, :same_page}

        0x01 ->
          index =
            case opcode &&& 0xF0 do
              result when result in [0x90, 0xB0] ->
                :y

              _ ->
                :x
            end

          zero_page_address(index)

        0x02 ->
          {:ok, 0x00, :same_page}

        0x03 ->
          index =
            case opcode &&& 0xF0 do
              result when result in [0x90, 0xB0] ->
                :y

              _ ->
                :x
            end

          absolute_address(index)
      end
    end
    |> case do
      {:ok, address} ->
        {:ok, address, :same_page}

      result ->
        result
    end
  end

  def unofficial_address(opcode) do
    if (opcode &&& 0x10) == 0x00 do
      case opcode >>> 2 &&& 0x03 do
        0x00 ->
          indirect_address(:x)

        0x01 ->
          zero_page_address()

        0x02 ->
          immediate_address()

        0x03 ->
          absolute_address()
      end
    else
      case opcode >>> 2 &&& 0x03 do
        0x00 ->
          indirect_address(:y)

        0x01 ->
          index =
            case opcode &&& 0xF0 do
              result when result in [0x90, 0xB0] ->
                :y

              _ ->
                :x
            end

          zero_page_address(index)

        0x02 ->
          absolute_address(:y)

        0x03 ->
          index =
            if opcode == 0x9C do
              :x
            else
              case opcode &&& 0xF0 do
                result when result in [0x90, 0xB0] ->
                  :y

                _ ->
                  :x
              end
            end

          absolute_address(index)
      end
    end
    |> case do
      {:ok, address} ->
        {:ok, address, :same_page}

      result ->
        result
    end
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

  defp handle_indexed_address(value, index) do
    result = value + index

    if Memory.same_page?(value, result) do
      {:ok, result, :same_page}
    else
      {:ok, result, :page_cross}
    end
  end
end
