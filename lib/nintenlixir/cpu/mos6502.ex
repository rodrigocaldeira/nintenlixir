defmodule Nintenlixir.CPU.MOS6502 do
  use GenServer
  use Bitwise

  # API

  alias Nintenlixir.CPU.Instructions
  alias Nintenlixir.Memory

  @carry_flag 1
  @zero_flag 2
  @interrupt_disable 4
  @decimal_mode 8
  @break_command 16
  @unused 32
  @overflow_flag 64
  @negative_flag 128

  def start_link(_) do
    GenServer.start_link(__MODULE__, new_cpu(), name: __MODULE__)
  end

  def get_state, do: GenServer.call(__MODULE__, :get_state)

  def set_state(state) do
    GenServer.call(__MODULE__, {:set_state, state})
  end

  def reset do
    :ok = Memory.reset(memory_server_name())
    :ok = GenServer.call(__MODULE__, :reset)
  end

  def get_registers, do: GenServer.call(__MODULE__, :get_registers)

  def set_registers(registers), do: GenServer.call(__MODULE__, {:set_registers, registers})

  def push(value), do: GenServer.call(__MODULE__, {:push, value})

  def push16(value) do
    :ok = push(value >>> 8)
    :ok = push(value &&& 0x00FF)
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
    %{
      irq: irq,
      nmi: nmi,
      rst: rst
    } = GenServer.call(__MODULE__, :get_state)

    cycles =
      case [irq, nmi, rst] do
        [false, false, false] -> 0
        _ -> 7
      end

    %{processor_status: p} = get_registers()

    if irq && (p &&& @interrupt_disable) == 0 do
      %{program_counter: pc} = get_registers()

      :ok = push16(pc)

      :ok =
        push(
          (p ||| @unused) &&&
            ~~~@break_command
        )

      p = p ||| @interrupt_disable

      {:ok, low} = read_memory(0xFFFE)
      {:ok, high} = read_memory(0xFFFF)

      pc = high <<< 8 ||| low

      :ok =
        set_registers(%{
          get_registers()
          | program_counter: pc,
            processor_status: p
        })
    end

    if nmi do
      %{
        program_counter: pc,
        processor_status: p
      } = get_registers()

      :ok = push16(pc)

      :ok =
        push(
          (p ||| @unused) &&&
            ~~~@break_command
        )

      p = p ||| @interrupt_disable

      {:ok, low} = read_memory(0xFFFA)
      {:ok, high} = read_memory(0xFFFB)

      pc = high <<< 8 ||| low

      :ok =
        set_registers(%{
          get_registers()
          | program_counter: pc,
            processor_status: p
        })
    end

    if rst do
      :ok = GenServer.call(__MODULE__, :reset)
    end

    state = GenServer.call(__MODULE__, :get_state)

    :ok =
      GenServer.call(
        __MODULE__,
        {:set_state,
         %{
           state
           | irq: false,
             nmi: false,
             rst: false
         }}
      )

    {:ok, cycles}
  end

  def set_Z_flag(0x00) do
    %{processor_status: p} = registers = get_registers()

    :ok =
      set_registers(%{
        registers
        | processor_status: p ||| @zero_flag
      })

    {:ok, 0x00}
  end

  def set_Z_flag(value) do
    %{processor_status: p} = registers = get_registers()

    :ok =
      set_registers(%{
        registers
        | processor_status: p &&& ~~~@zero_flag
      })

    {:ok, value}
  end

  def set_N_flag(value) do
    %{processor_status: p} = registers = get_registers()

    :ok =
      set_registers(%{
        registers
        | processor_status:
            (p &&& ~~~@negative_flag) |||
              (value &&& @negative_flag)
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
            (p &&& ~~~@carry_flag) |||
              (value >>> 8 &&& @carry_flag)
      })

    {:ok, value}
  end

  def set_V_flag_addition(term1, term2, result) do
    %{processor_status: p} = registers = get_registers()

    :ok =
      set_registers(%{
        registers
        | processor_status:
            (p &&& ~~~@overflow_flag) |||
              (~~~(bxor(term1, term2)) &&& bxor(term1, result) &&&
                 @negative_flag) >>> 1
      })

    {:ok, result}
  end

  def immediate_address do
    %{program_counter: pc} = registers = get_registers()
    :ok = set_registers(%{registers | program_counter: pc + 1 &&& 0xFFFF})
    {:ok, pc}
  end

  def zero_page_address do
    %{program_counter: pc} = registers = get_registers()
    {:ok, result} = read_memory(pc)
    :ok = set_registers(%{registers | program_counter: pc + 1 &&& 0xFFFF})
    {:ok, result}
  end

  def zero_page_address(register) when is_atom(register) and register in [:x, :y] do
    {:ok, value} = zero_page_address()
    registers = get_registers()
    register_value = Map.get(registers, register)
    {:ok, register_value + value &&& 0xFFFF}
  end

  def relative_address do
    %{program_counter: pc} = registers = get_registers()
    {:ok, value} = read_memory(pc)
    pc = pc + 1 &&& 0xFFFF
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
    :ok = set_registers(%{registers | program_counter: pc + 2 &&& 0xFFFF})

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
    :ok = set_registers(%{registers | program_counter: pc + 2 &&& 0xFFFF})

    address_high = high <<< 8 ||| low + 1
    address_low = high <<< 8 ||| low

    {:ok, low} = read_memory(address_low)
    {:ok, high} = read_memory(address_high)

    {:ok, high <<< 8 ||| low}
  end

  def indirect_address(:x) do
    %{program_counter: pc, x: x} = registers = get_registers()
    {:ok, value} = read_memory(pc)
    address = (value + x) &&& 0xFFFF
    :ok = set_registers(%{registers | program_counter: (pc + 1) &&& 0xFFFF})

    {:ok, low} = read_memory(address)
    {:ok, high} = read_memory((address + 1) &&& 0x00FF)

    {:ok, high <<< 8 ||| low}
  end

  def indirect_address(:y) do
    %{program_counter: pc, y: y} = registers = get_registers()
    :ok = set_registers(%{registers | program_counter: pc + 1 &&& 0xFFFF})

    {:ok, address} = read_memory(pc)
    address = address &&& 0xFFFF
    {:ok, low} = read_memory(address)
    {:ok, high} = read_memory((address + 1) &&& 0x00FF)

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
    :ok = write_memory(address, a &&& x)
  end

  def sta(address) do
    %{accumulator: a} = get_registers()
    :ok = write_memory(address, a)
  end

  def stx(address) do
    %{x: x} = get_registers()
    :ok = write_memory(address, x)
  end

  def sty(address) do
    %{y: y} = get_registers()
    :ok = write_memory(address, y)
  end

  def transfer(from, to) do
    registers = get_registers()
    value_from = Map.get(registers, from)
    {:ok, ^value_from} = set_ZN_flags(value_from)

    get_registers()
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
    :ok = set_registers(%{registers | stack_pointer: x})
  end

  def pha do
    %{accumulator: a} = get_registers()
    :ok = push(a)
  end

  def php do
    %{processor_status: p} = get_registers()
    :ok = push(p ||| @break_command ||| @unused)
  end

  def pla do
    {:ok, value} = pop()
    {:ok, ^value} = set_ZN_flags(value)
    :ok = set_registers(%{get_registers() | accumulator: value})
  end

  def plp do
    {:ok, value} = pop()
    p = value &&& ~~~(@break_command ||| @unused)
    :ok = set_registers(%{get_registers() | processor_status: p})
  end

  def and_op(address) do
    {:ok, value} = read_memory(address)
    %{accumulator: a} = get_registers()
    {:ok, result} = set_ZN_flags(a &&& value)
    :ok = set_registers(%{get_registers() | accumulator: result})
  end

  def xor_op(address) do
    {:ok, value} = read_memory(address)
    %{accumulator: a} = get_registers()
    {:ok, result} = set_ZN_flags(bxor(a, value))
    :ok = set_registers(%{get_registers() | accumulator: result})
  end

  def or_op(address) do
    {:ok, value} = read_memory(address)
    %{accumulator: a} = get_registers()
    {:ok, result} = set_ZN_flags(a ||| value)
    :ok = set_registers(%{get_registers() | accumulator: result})
  end

  def bit(address) do
    {:ok, value} = read_memory(address)
    %{accumulator: a} = get_registers()
    {:ok, _} = set_Z_flag(value &&& a)

    %{processor_status: p} = get_registers()
    p =
      (p &&& ~~~(@negative_flag ||| @overflow_flag)) |||
        (value &&& (@negative_flag ||| @overflow_flag))

    :ok = set_registers(%{get_registers() | processor_status: p})
  end

  def disable_decimal_mode do
    :ok = GenServer.call(__MODULE__, {:set_state, %{get_state() | decimal_mode: false}})
  end

  def addition(value) do
    %{accumulator: a, processor_status: p} = get_registers()
    %{decimal_mode: decimal_mode} = get_state()
    a = a &&& 0xFFFF

    if !decimal_mode || (p &&& @decimal_mode) == 0 do
      {:ok, result} = set_C_flag_addition(a + value + ((p &&& @carry_flag) &&& 0xFFFF))
      result = result &&& 0xFF
      {:ok, ^result} = set_V_flag_addition(a, value, result)
      {:ok, ^result} = set_ZN_flags(result)
      :ok = set_registers(%{get_registers() | accumulator: result})
    else
      low = (a &&& 0x000F) + (value &&& 0x000F) + (p &&& @carry_flag)
      high = (a &&& 0x00F0) + (value &&& 0x00F0)

      {low, high} = 
        if low >= 0x000A do
          {low - 0x000A, high + 0x0010}
        else
          {low, high}
        end

      high =
        if high >= 0x00A0 do
          high - 0x00A0
        else
          high
        end

      {:ok, result} = set_C_flag_addition(high ||| (low &&& 0x000F))
      result = result &&& 0xFF
      {:ok, ^result} = set_V_flag_addition(a, value, result)
      {:ok, ^result} = set_ZN_flags(result)
      :ok = set_registers(%{get_registers() | accumulator: result})
    end
  end

  def adc(address) do
    {:ok, value} = read_memory(address)
    :ok = addition(value)
  end

  def sbc(address) do
    {:ok, value} = read_memory(address)

    %{processor_status: p} = get_registers()
    %{decimal_mode: decimal_mode} = get_state()

    value =
      if !decimal_mode || (p &&& @decimal_mode) == 0 do
        bxor(value, 0xFF)
      else
        0x99 - value
      end

    :ok = addition(value)
  end

  def compare(value1, value2) do
    value = bxor(value1, 0xFF) + 1
    {:ok, result} = set_C_flag_addition(value2 + value)
    result = result &&& 0xFF
    {:ok, ^result} = set_ZN_flags(result)
    :ok
  end

  def cmp(address) do
    {:ok, value} = read_memory(address)
    %{accumulator: a} = get_registers()
    :ok = compare(value, a)
  end

  def cpx(address) do
    {:ok, value} = read_memory(address)
    %{x: x} = get_registers()
    :ok = compare(value, x)
  end

  def cpy(address) do
    {:ok, value} = read_memory(address)
    %{y: y} = get_registers()
    :ok = compare(value, y)
  end

  def inc(ref), do: unary_op(ref, &Kernel.+/2)

  def dec(ref), do: unary_op(ref, &Kernel.-/2)

  defp unary_op(register, f) when is_atom(register) do
    registers = get_registers()
    value = f.(Map.get(registers, register), 1)
    value = value &&& 0xFF
    {:ok, ^value} = set_ZN_flags(value)
    :ok = set_registers(get_registers() |> Map.put(register, value))
  end

  defp unary_op(address, f) do
    {:ok, value} = read_memory(address)
    value = f.(value, 1) &&& 0xFF
    {:ok, ^value} = set_ZN_flags(value)
    :ok = write_memory(address, value)
  end

  def shift(:left, value, ref) do
    value = value <<< 1
    c = (value &&& @negative_flag) >>> 7
    :ok = update_shifted_value(value, c)
    :ok = store(value, ref)
  end

  def shift(:right, value, ref) do
    value = value >>> 1
    c = value &&& @carry_flag
    :ok = update_shifted_value(value, c)
    :ok = store(value, ref)
  end

  def rotate(:left, value, ref) do
    %{processor_status: p} = get_registers()

    c = (value &&& @negative_flag) >>> 7
    value =
      ((value <<< 1 &&& ~~~@carry_flag) |||
        (p &&& @carry_flag)) &&& 0x00FF

    :ok = update_shifted_value(value, c)
    :ok = store(value, ref)
  end

  def rotate(:right, value, ref) do
    %{processor_status: p} = get_registers()

    c = value &&& @carry_flag
    value =
      (value >>> 1 &&& ~~~@negative_flag) |||
        (p &&& @carry_flag) <<< 7

    :ok = update_shifted_value(value, c)
    :ok = store(value, ref)
  end

  defp store(value, ref) when is_atom(ref),
    do: set_registers(get_registers() |> Map.put(ref, value))

  defp store(value, ref), do: write_memory(ref, value)

  defp update_shifted_value(value, carry) do
    %{processor_status: p} = registers = get_registers()
    p = p &&& ~~~@carry_flag
    p = p ||| carry
    set_registers(%{registers | processor_status: p})
    {:ok, ^value} = set_ZN_flags(value)
    :ok
  end

  def jmp(address), do: set_registers(%{get_registers() | program_counter: address})

  def jsr(address) do
    %{program_counter: pc} = get_registers()
    value = pc - 1 &&& 0xFFFF
    :ok = push16(value)
    :ok = set_registers(%{get_registers() | program_counter: address})
  end

  def rts do
    {:ok, value} = pop16()
    :ok = set_registers(%{get_registers() | program_counter: value + 1 &&& 0xFFFF})
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
      (p &&& @carry_flag) == 0
    end

    {:ok, _} = branch(address, f)
  end

  def bcs(address) do
    f = fn ->
      %{processor_status: p} = get_registers()
      (p &&& @carry_flag) != 0
    end

    {:ok, _} = branch(address, f)
  end

  def beq(address) do
    f = fn ->
      %{processor_status: p} = get_registers()
      (p &&& @zero_flag) != 0
    end

    {:ok, _} = branch(address, f)
  end

  def bmi(address) do
    f = fn ->
      %{processor_status: p} = get_registers()
      (p &&& @negative_flag) != 0
    end

    {:ok, _} = branch(address, f)
  end

  def bne(address) do
    f = fn ->
      %{processor_status: p} = get_registers()
      (p &&& @zero_flag) == 0
    end

    {:ok, _} = branch(address, f)
  end

  def bpl(address) do
    f = fn ->
      %{processor_status: p} = get_registers()
      (p &&& @negative_flag) == 0
    end

    {:ok, _} = branch(address, f)
  end

  def bvc(address) do
    f = fn ->
      %{processor_status: p} = get_registers()
      (p &&& @overflow_flag) == 0
    end

    {:ok, _} = branch(address, f)
  end

  def bvs(address) do
    f = fn ->
      %{processor_status: p} = get_registers()
      (p &&& @overflow_flag) != 0
    end

    {:ok, _} = branch(address, f)
  end

  def clc, do: clear_processor_status_flag(@carry_flag)
  def cld, do: clear_processor_status_flag(@decimal_mode)
  def cli, do: clear_processor_status_flag(@interrupt_disable)
  def clv, do: clear_processor_status_flag(@overflow_flag)

  defp clear_processor_status_flag(flag) do
    %{processor_status: p} = get_registers()
    p = p &&& ~~~flag
    :ok = set_registers(%{get_registers() | processor_status: p})
  end

  def sec, do: set_processor_status_flag(@carry_flag)
  def sed, do: set_processor_status_flag(@decimal_mode)
  def sei, do: set_processor_status_flag(@interrupt_disable)

  defp set_processor_status_flag(flag) do
    %{processor_status: p} = get_registers()
    p = p ||| flag
    :ok = set_registers(%{get_registers() | processor_status: p})
  end

  def brk do
    %{program_counter: pc, processor_status: p} = get_registers()
    pc = pc + 1 &&& 0xFFFF
    :ok = push16(pc)
    :ok = push(p ||| @break_command ||| @unused)

    p = p ||| @interrupt_disable

    {:ok, low} = read_memory(0xFFFE)
    {:ok, high} = read_memory(0xFFFF)

    pc = high <<< 8 ||| low
    :ok = set_registers(%{get_registers() | program_counter: pc, processor_status: p})
  end

  def noop, do: :ok
  def noop(_), do: :ok

  def asl do
    %{accumulator: a} = get_registers()
    :ok = shift(:left, a, :accumulator)
  end

  def asl(address) do
    {:ok, value} = read_memory(address)
    :ok = shift(:left, value, address)
  end

  def lsr do
    %{accumulator: a} = get_registers()
    :ok = shift(:right, a, :accumulator)
  end

  def lsr(address) do
    {:ok, value} = read_memory(address)
    :ok = shift(:right, value, address)
  end

  def rol do
    %{accumulator: a} = get_registers()
    :ok = rotate(:left, a, :accumulator)
  end

  def rol(address) do
    {:ok, value} = read_memory(address)
    :ok = rotate(:left, value, address)
  end

  def ror do
    %{accumulator: a} = get_registers()
    :ok = rotate(:right, a, :accumulator)
  end

  def ror(address) do
    {:ok, value} = read_memory(address)
    :ok = rotate(:right, value, address)
  end

  def anc(address) do
    :ok = and_op(address)
    %{processor_status: p} = get_registers()
    p = (p &&& ~~~@carry_flag) ||| p >>> 7
    :ok = set_registers(%{get_registers() | processor_status: p})
  end

  def alr(address) do
    :ok = and_op(address)
    %{accumulator: a} = get_registers()
    :ok = shift(:right, a, :accumulator)
  end

  def arr(address) do
    :ok = and_op(address)
    %{accumulator: a} = get_registers()
    :ok = rotate(:right, a, :accumulator)
  end

  def shy(_), do: :ok
  def shx(_), do: :ok

  def axs(address) do
    {:ok, value} = read_memory(address)
    %{accumulator: a, x: x} = get_registers()
    x = x &&& a
    :ok = compare(value, x)
    x = x - value
    :ok = set_registers(%{get_registers() | x: x})
  end

  def rti do
    {:ok, p} = pop()
    p = p &&& ~~~(@break_command ||| @unused)
    {:ok, pc} = pop16()
    :ok = set_registers(%{get_registers() | program_counter: pc, processor_status: p})
  end

  def dcp(address) do
    :ok = dec(address)
    :ok = cmp(address)
  end

  def isb(address) do
    :ok = inc(address)
    :ok = sbc(address)
  end

  def slo(address) do
    {:ok, value} = read_memory(address)
    :ok = shift(:left, value, address)
    %{accumulator: a} = get_registers()
    a = a ||| value
    {:ok, ^a} = set_ZN_flags(a)
    :ok = set_registers(%{get_registers() | accumulator: a})
  end

  def rla(address) do
    {:ok, value} = read_memory(address)
    :ok = rotate(:left, value, address)
    :ok = and_op(address)
  end

  def sre(address) do
    {:ok, value} = read_memory(address)
    :ok = rotate(:right, value, address)
    :ok = xor_op(address)
  end

  def rra(address) do
    {:ok, value} = read_memory(address)
    :ok = rotate(:right, value, address)
    :ok = adc(address)
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
          indirect_address(:y)

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

  defp format_hex(number), do: Integer.to_string(number, 16)

  def debug(
        %{accumulator: a, x: x, y: y, program_counter: pc, stack_pointer: sp, processor_status: p} =
          term
      ) do
    if debug_enabled() do
      IO.inspect(
        "A: #{format_hex(a)}, X: #{format_hex(x)}, Y: #{format_hex(y)}, PC: #{format_hex(pc)}, SP: #{format_hex(sp)}, P: #{format_hex(p)}"
      )
    end

    term
  end

  def debug(term) do
    if debug_enabled() do
      IO.inspect(term)
    end

    term
  end

  defp debug_enabled, do: System.get_env("NINTENLIXIR_DEBUG", "false") |> String.to_atom()

  def step do
    get_state() |> debug()

    {:ok, cycles} = interrupt()

    %{program_counter: pc} = get_registers() |> debug()

    {:ok, opcode} = read_memory(pc) |> debug()

    if Instructions.valid_opcode?(opcode) do
      pc = pc + 1 &&& 0xFFFF

      set_registers(%{get_registers() | program_counter: pc})

      case Instructions.execute(opcode) do
        {:ok, inst_cycles} ->
          {:ok, cycles + inst_cycles}
      end
    else
        {:error, {:invalid_opcode, 0}}
    end
  end

  def run do
    step()
    |> case do
      {:ok, _} -> run()
      error -> error
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

    {:reply, :ok, %{state | registers: %{new_registers() | program_counter: pc}}}
  end

  def handle_call(:get_registers, _, %{registers: registers} = state) do
    {:reply, registers, state}
  end

  def handle_call(
        {:set_registers,
         %{
           accumulator: accumulator,
           x: x,
           y: y,
           processor_status: processor_status,
           stack_pointer: stack_pointer,
           program_counter: program_counter
         }},
        _,
        state
      ) do
    registers = %{
      accumulator: accumulator &&& 0xFF,
      x: x &&& 0xFF,
      y: y &&& 0xFF,
      processor_status: processor_status,
      stack_pointer: stack_pointer &&& 0xFF,
      program_counter: program_counter &&& 0xFFFF
    }

    {:reply, :ok, %{state | registers: registers}}
  end

  def handle_call({:push, value}, _, %{registers: registers} = state) do
    %{stack_pointer: sp} = registers

    :ok = write_memory(0x0100 ||| sp, value)

    {:reply, :ok, %{state | registers: %{registers | stack_pointer: sp - 1}}}
  end

  def handle_call(:pop, _, %{registers: registers} = state) do
    %{stack_pointer: sp} = registers

    sp = sp + 1

    {:ok, value} = read_memory(0x0100 ||| sp)

    {:reply, {:ok, value}, %{state | registers: %{registers | stack_pointer: sp}}}
  end

  def handle_call({:receive_interrupt, :irq}, _, state), do: {:reply, :ok, %{state | irq: true}}
  def handle_call({:receive_interrupt, :nmi}, _, state), do: {:reply, :ok, %{state | nmi: true}}
  def handle_call({:receive_interrupt, :rst}, _, state), do: {:reply, :ok, %{state | rst: true}}

  def handle_call({:set_state, new_state}, _, _), do: {:reply, :ok, new_state}

  # Helpers

  defp new_cpu() do
    %{
      decimal_mode: true,
      break_error: false,
      nmi: false,
      irq: false,
      rst: false,
      registers: new_registers()
    }
  end

  defp new_registers() do
    %{
      accumulator: 0,
      x: 0,
      y: 0,
      processor_status: 36,
      stack_pointer: 0xFD,
      program_counter: 0xFFFC
    }
  end

  def memory_server_name, do: :memory_cpu

  def read_memory(address), do: Memory.read(memory_server_name(), address)
  def write_memory(address, value), do: Memory.write(memory_server_name(), address, value)

  defp handle_indexed_address(value, index) do
    result = value + index &&& 0xFFFF

    if Memory.same_page?(value, result) do
      {:ok, result, :same_page}
    else
      {:ok, result, :page_cross}
    end
  end
end
