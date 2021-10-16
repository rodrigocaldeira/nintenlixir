defmodule Nintenlixir.ROM do
  use Bitwise
  use GenServer

  @header_offset 16
  @rom_bank_length 1024 * 16
  @vrom_bank_length 1024 * 8
  @wram_bank_length 1024 * 8

  defstruct name: "",
            prg_banks: nil,
            chr_banks: nil,
            mirroring: :horizontal,
            battery?: false,
            trainer?: false,
            vs_cart?: false,
            mapper_id: nil,
            mapper: nil,
            ram_banks: nil,
            region: :ntsc,
            trainer_data: nil,
            rom_banks: nil,
            vrom_banks: nil,
            wram_banks: nil,
            irq: nil,
            set_tables: nil

  alias __MODULE__

  def start_link(_) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  def load(file, irq, set_tables) do
    with {:ok, data} <- File.read(file),
         :ok <- validate_rom_data(data) do
      rom =
        %ROM{}
        |> define_name(file)
        |> define_prg_banks(data)
        |> define_chr_banks(data)
        |> define_mirroring(data)
        |> define_battery(data)
        |> define_trainer(data)
        |> define_ram_banks(data)
        |> define_region(data)
        |> define_vs_cart(data)
        |> define_mapper_id(data)
        |> define_mapper()
        |> load_trainer_data(data)
        |> load_rom_banks(data)
        |> load_vrom_banks(data)
        |> create_wram_banks()
        |> define_interrupt(irq)
        |> define_set_tables(set_tables)
        |> execute_set_tables()

      GenServer.call(__MODULE__, {:set_state, rom})
    end
  end

  def get_state, do: GenServer.call(__MODULE__, :get_state)

  def set_state(state) do
    GenServer.call(__MODULE__, {:set_state, state})
  end

  def get_tables(%ROM{mirroring: :horizontal}), do: [0, 0, 1, 1]
  def get_tables(%ROM{mirroring: :vertical}), do: [0, 1, 0, 1]
  def get_tables(_), do: [0, 0, 1, 1]

  def get_mapper do
    %ROM{mapper: mapper} = get_state()
    mapper
  end

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_state, _, state) do
    {:reply, state, state}
  end

  def handle_call({:set_state, new_state}, _, _), do: {:reply, :ok, new_state}

  defp define_name(%ROM{} = rom, file) do
    %{rom | name: file |> Path.basename() |> Path.rootname()}
  end

  defp define_prg_banks(%ROM{} = rom, data) do
    <<prg_banks::8>> = binary_part(data, 4, 1)
    %{rom | prg_banks: prg_banks}
  end

  defp define_chr_banks(%ROM{} = rom, data) do
    <<chr_banks::8>> = binary_part(data, 5, 1)
    %{rom | chr_banks: chr_banks}
  end

  defp define_mirroring(%ROM{} = rom, data) do
    <<byte::8>> = binary_part(data, 6, 1)

    cond do
      (byte &&& 0x01 <<< 3) != 0x00 ->
        %{rom | mirroring: :four_screen}

      (byte &&& 0x01 <<< 0) != 0x00 ->
        %{rom | mirroring: :vertical}

      true ->
        rom
    end
  end

  defp define_battery(%ROM{} = rom, data) do
    <<byte::8>> = binary_part(data, 6, 1)
    battery = (byte &&& 0x01 <<< 1) != 0
    %{rom | battery?: battery}
  end

  defp define_trainer(%ROM{} = rom, data) do
    <<byte::8>> = binary_part(data, 6, 1)
    trainer = (byte &&& 0x01 <<< 2) != 0
    %{rom | trainer?: trainer}
  end

  defp define_ram_banks(%ROM{} = rom, data) do
    <<ram_banks::8>> = binary_part(data, 8, 1)

    case ram_banks do
      0 ->
        %{rom | ram_banks: 1}

      ram_banks ->
        %{rom | ram_banks: ram_banks}
    end
  end

  defp define_region(%ROM{} = rom, data) do
    <<byte::8>> = binary_part(data, 9, 1)

    cond do
      (byte &&& 0x01) != 0 ->
        %{rom | region: :pal}

      true ->
        rom
    end
  end

  defp define_vs_cart(%ROM{} = rom, data) do
    <<byte::8>> = binary_part(data, 7, 1)
    vs_cart = (byte &&& 0x01) != 0
    %{rom | vs_cart?: vs_cart}
  end

  defp define_mapper_id(%ROM{} = rom, data) do
    <<byte::8>> = binary_part(data, 6, 1)
    mapper_id = byte >>> 4 &&& 0x0F
    <<byte::8>> = binary_part(data, 7, 1)
    mapper_id = mapper_id ||| (byte &&& 0xF0)
    %{rom | mapper_id: mapper_id}
  end

  defp define_mapper(%ROM{mapper_id: mapper_id} = rom) when mapper_id in [0x00, 0x40, 0x41] do
    %{rom | mapper: %Nintenlixir.ROM.Mappers.NROM{}}
  end

  defp define_mapper(%ROM{} = rom), do: %{rom | mapper: :unknown}

  defp load_trainer_data(%ROM{trainer?: false} = rom, _), do: rom

  defp load_trainer_data(%ROM{trainer?: true} = rom, data) do
    trainer_data = load_rom_data(data, @header_offset, 512)
    %{rom | trainer_data: trainer_data}
  end

  defp load_rom_banks(%ROM{prg_banks: 0} = rom, _), do: rom

  defp load_rom_banks(%ROM{prg_banks: prg_banks} = rom, data) do
    trainer_offset = calculate_trainer_offset(rom)
    prg_banks_data = load_rom_data(data, trainer_offset, @rom_bank_length * prg_banks)

    rom_banks =
      Enum.map(0..(prg_banks - 1), fn prg_bank_index ->
        Enum.slice(prg_banks_data, prg_bank_index * @rom_bank_length, @rom_bank_length)
      end)

    %{rom | rom_banks: rom_banks}
  end

  defp load_vrom_banks(%ROM{chr_banks: 0} = rom, _), do: rom

  defp load_vrom_banks(%ROM{chr_banks: chr_banks} = rom, data) do
    rom_banks_offset = calculate_rom_banks_offset(rom)
    chr_banks_data = load_rom_data(data, rom_banks_offset, @vrom_bank_length * chr_banks)

    vrom_banks =
      Enum.map(0..(chr_banks - 1), fn chr_bank_index ->
        Enum.slice(chr_banks_data, chr_bank_index * @vrom_bank_length, @vrom_bank_length)
      end)

    %{rom | vrom_banks: vrom_banks}
  end

  defp create_wram_banks(%ROM{ram_banks: 0} = rom), do: rom

  defp create_wram_banks(%ROM{ram_banks: ram_banks} = rom) do
    wram_banks =
      Enum.map(0..(ram_banks - 1), fn _ ->
        List.duplicate(0x00, @wram_bank_length)
      end)

    %{rom | wram_banks: wram_banks}
  end

  defp execute_set_tables(%ROM{set_tables: set_tables} = rom) do
    set_tables.(get_tables(rom))
    rom
  end

  defp define_interrupt(%ROM{} = rom, interrupt) do
    %{rom | irq: interrupt}
  end

  defp define_set_tables(%ROM{} = rom, set_tables) do
    %{rom | set_tables: set_tables}
  end

  defp calculate_trainer_offset(%ROM{trainer?: false}), do: @header_offset
  defp calculate_trainer_offset(%ROM{trainer?: true}), do: @header_offset + 512

  defp calculate_rom_banks_offset(%ROM{prg_banks: prg_banks} = rom) do
    trainer_offset = calculate_trainer_offset(rom)
    trainer_offset + @rom_bank_length * prg_banks
  end

  defp load_rom_data(data, start, length) do
    binary_part(data, start, length) |> :binary.bin_to_list()
  end

  defp validate_rom_data(data) when length(data) < @header_offset do
    {:error, :missing_header}
  end

  defp validate_rom_data(data)
       when binary_part(data, 0, 3) != "NES" and binary_part(data, 3, 1) != <<26>> do
    {:error, :missing_constant_header}
  end

  defp validate_rom_data(_), do: :ok
end
