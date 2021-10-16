defmodule Nintenlixir.Console do
  use GenServer
  use Bitwise

  alias Nintenlixir.CPU.MOS6502

  alias Nintenlixir.PPU.{
    PPUMapper,
    RP2C02
  }

  alias Nintenlixir.Memory
  alias Nintenlixir.ROM
  alias Nintenlixir.PPU.NameTableMapper

  def start_link(_) do
    GenServer.start_link(__MODULE__, new_console(), name: __MODULE__)
  end

  def get_state, do: GenServer.call(__MODULE__, :get_state)
  def set_state(state), do: GenServer.call(__MODULE__, {:set_state, state})

  def t do
    insert_test_cartridge()
    power_on()
  end

  def insert_test_cartridge do
    Path.join(:code.priv_dir(:nintenlixir), 'nestest.nes')
    |> ROM.load(&MOS6502.irq/0, &NameTableMapper.set_tables/1)
  end

  def insert_cartridge(file) do
    ROM.load(file, &MOS6502.irq/0, &NameTableMapper.set_tables/1)
  end

  def power_on() do
    reset()
    Memory.add_mapper(MOS6502.memory_server_name(), %PPUMapper{}, :cpu)
    Memory.add_mapper(MOS6502.memory_server_name(), ROM.get_mapper(), :cpu)

    # TODO: transport this to CPU in RP2A03 module after implement APU
    set_cpu_mirroring()

    Memory.add_mapper(RP2C02.memory_server_name(), ROM.get_mapper(), :ppu)
    Memory.add_mapper(RP2C02.memory_server_name(), %PPUMapper{}, :ppu)

    RP2C02.define_interrupt(&MOS6502.nmi/0)
    schedule_execution()
  end

  def set_cpu_mirroring do
    ram =
      Enum.map(0x0800..0x1FFF, fn address ->
        {address, rem(address, 0x0800)}
      end)
      |> Map.new()

    ppu_registers =
      Enum.map(0x2008..0x3FFF, fn address ->
        {address, 0x2000 + (address &&& 0x0007)}
      end)
      |> Map.new()

    Memory.set_mirrors(MOS6502.memory_server_name(), ram)
    Memory.set_mirrors(MOS6502.memory_server_name(), ppu_registers)
  end

  def step(state) do
    %{ppu_quota: ppu_quota} = state
    {:ok, cycles} = MOS6502.step()
    ppu_quota = ppu_quota + cycles * 3
    ppu_quota = step_ppu(ppu_quota)
    %{state | ppu_quota: ppu_quota}
  end

  def step_ppu(ppu_quota) when ppu_quota > 1 do
    RP2C02.execute()
    |> IO.inspect(limit: :infinity)

    step_ppu(ppu_quota - 1)
  end

  def step_ppu(ppu_quota), do: ppu_quota

  def reset() do
    MOS6502.reset()
    RP2C02.reset()
  end

  # Server

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_info(:execute, state) do
    state = step(state)
    schedule_execution()
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get_state, _, state) do
    {:reply, state, state}
  end

  def handle_call({:set_state, state}, _, _) do
    {:reply, :ok, state}
  end

  defp new_console do
    %{
      ppu_quota: 0
    }
  end

  defp schedule_execution do
    Process.send_after(__MODULE__, :execute, 1)
  end
end
