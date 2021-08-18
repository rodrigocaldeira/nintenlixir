defmodule Nintenlixir.CPU.Instructions do
  alias Nintenlixir.CPU.MOS6502
  use Bitwise

  @cycles [
    7,
    6,
    0,
    8,
    3,
    3,
    5,
    5,
    3,
    2,
    2,
    2,
    4,
    4,
    6,
    6,
    2,
    5,
    0,
    8,
    4,
    4,
    6,
    6,
    2,
    4,
    2,
    7,
    4,
    4,
    7,
    7,
    6,
    6,
    0,
    8,
    3,
    3,
    5,
    5,
    4,
    2,
    2,
    2,
    4,
    4,
    6,
    6,
    2,
    5,
    0,
    8,
    4,
    4,
    6,
    6,
    2,
    4,
    2,
    7,
    4,
    4,
    7,
    7,
    6,
    6,
    0,
    8,
    3,
    3,
    5,
    5,
    3,
    2,
    2,
    2,
    3,
    4,
    6,
    6,
    2,
    5,
    0,
    8,
    4,
    4,
    6,
    6,
    2,
    4,
    2,
    7,
    4,
    4,
    7,
    7,
    6,
    6,
    0,
    8,
    3,
    3,
    5,
    5,
    4,
    2,
    2,
    2,
    5,
    4,
    6,
    6,
    2,
    5,
    0,
    8,
    4,
    4,
    6,
    6,
    2,
    4,
    2,
    7,
    4,
    4,
    7,
    7,
    2,
    6,
    2,
    6,
    3,
    3,
    3,
    3,
    2,
    2,
    2,
    2,
    4,
    4,
    4,
    4,
    2,
    6,
    0,
    6,
    4,
    4,
    4,
    4,
    2,
    5,
    2,
    5,
    5,
    5,
    5,
    5,
    2,
    6,
    2,
    6,
    3,
    3,
    3,
    3,
    2,
    2,
    2,
    2,
    4,
    4,
    4,
    4,
    2,
    5,
    0,
    5,
    4,
    4,
    4,
    4,
    2,
    4,
    2,
    4,
    4,
    4,
    4,
    4,
    2,
    6,
    2,
    8,
    3,
    3,
    5,
    5,
    2,
    2,
    2,
    2,
    4,
    4,
    6,
    6,
    2,
    5,
    0,
    8,
    4,
    4,
    6,
    6,
    2,
    4,
    2,
    7,
    4,
    4,
    7,
    7,
    2,
    6,
    2,
    8,
    3,
    3,
    5,
    5,
    2,
    2,
    2,
    2,
    4,
    4,
    6,
    6,
    2,
    5,
    0,
    8,
    4,
    4,
    6,
    6,
    2,
    4,
    2,
    7,
    4,
    4,
    7,
    7
  ]

  @cycles_page_cross [
    7,
    6,
    0,
    8,
    3,
    3,
    5,
    5,
    3,
    2,
    2,
    2,
    4,
    4,
    6,
    6,
    3,
    6,
    0,
    8,
    4,
    4,
    6,
    6,
    2,
    5,
    2,
    7,
    5,
    5,
    7,
    7,
    6,
    6,
    0,
    8,
    3,
    3,
    5,
    5,
    4,
    2,
    2,
    2,
    4,
    4,
    6,
    6,
    3,
    6,
    0,
    8,
    4,
    4,
    6,
    6,
    2,
    5,
    2,
    7,
    5,
    5,
    7,
    7,
    6,
    6,
    0,
    8,
    3,
    3,
    5,
    5,
    3,
    2,
    2,
    2,
    3,
    4,
    6,
    6,
    3,
    6,
    0,
    8,
    4,
    4,
    6,
    6,
    2,
    5,
    2,
    7,
    5,
    5,
    7,
    7,
    6,
    6,
    0,
    8,
    3,
    3,
    5,
    5,
    4,
    2,
    2,
    2,
    5,
    4,
    6,
    6,
    3,
    6,
    0,
    8,
    4,
    4,
    6,
    6,
    2,
    5,
    2,
    7,
    5,
    5,
    7,
    7,
    2,
    6,
    2,
    6,
    3,
    3,
    3,
    3,
    2,
    2,
    2,
    2,
    4,
    4,
    4,
    4,
    3,
    6,
    0,
    6,
    4,
    4,
    4,
    4,
    2,
    5,
    2,
    5,
    5,
    5,
    5,
    5,
    2,
    6,
    2,
    6,
    3,
    3,
    3,
    3,
    2,
    2,
    2,
    2,
    4,
    4,
    4,
    4,
    3,
    6,
    0,
    6,
    4,
    4,
    4,
    4,
    2,
    5,
    2,
    5,
    5,
    5,
    5,
    5,
    2,
    6,
    2,
    8,
    3,
    3,
    5,
    5,
    2,
    2,
    2,
    2,
    4,
    4,
    6,
    6,
    3,
    6,
    0,
    8,
    4,
    4,
    6,
    6,
    2,
    5,
    2,
    7,
    5,
    5,
    7,
    7,
    2,
    6,
    2,
    8,
    3,
    3,
    5,
    5,
    2,
    2,
    2,
    2,
    4,
    4,
    6,
    6,
    3,
    6,
    0,
    8,
    4,
    4,
    6,
    6,
    2,
    5,
    2,
    7,
    5,
    5,
    7,
    7
  ]

  # Available instructions OpCodes

  @lda [0xA1, 0xA5, 0xA9, 0xAD, 0xB1, 0xB5, 0xB9, 0xBD]
  @ldx [0xA2, 0xA6, 0xAE, 0xB6, 0xBE]
  @ldy [0xA0, 0xA4, 0xAC, 0xB4, 0xBC]
  @sta [0x81, 0x85, 0x8D, 0x91, 0x95, 0x99, 0x9D]
  @stx [0x86, 0x8E, 0x96]
  @sty [0x84, 0x8C, 0x94]
  @tax 0xAA
  @tay 0xA8
  @txa 0x8A
  @tya 0x98
  @tsx 0xBA
  @pha 0x48
  @php 0x08
  @pla 0x68
  @plp 0x28
  @and_op [0x21, 0x25, 0x29, 0x2D, 0x31, 0x35, 0x39, 0x3D]
  @xor_op [0x41, 0x45, 0x49, 0x4D, 0x51, 0x55, 0x59, 0x5D]
  @or_op [0x01, 0x05, 0x09, 0x0D, 0x11, 0x15, 0x19, 0x1D]
  @bit [0x24, 0x2C]
  @adc [0x61, 0x65, 0x69, 0x6D, 0x71, 0x75, 0x79, 0x7D]
  @sbc [0xE1, 0xE5, 0xEB, 0xE9, 0xED, 0xF1, 0xF5, 0xF9, 0xFD]
  @dcp [0xC3, 0xC7, 0xCF, 0xD3, 0xD7, 0xDB, 0xDF]
  @isb [0xE3, 0xE7, 0xEF, 0xF3, 0xF7, 0xFB, 0xFF]
  @slo [0x03, 0x07, 0x0F, 0x13, 0x17, 0x1B, 0x1F]
  @rla [0x23, 0x27, 0x2F, 0x33, 0x37, 0x3B, 0x3F]
  @sre [0x43, 0x47, 0x4F, 0x53, 0x57, 0x5B, 0x5F]
  @rra [0x63, 0x67, 0x6F, 0x73, 0x77, 0x7B, 0x7F]
  @cmp [0xC1, 0xC5, 0xC9, 0xCD, 0xD1, 0xD5, 0xD9, 0xDD]
  @cpx [0xE0, 0xE4, 0xEC]
  @cpy [0xC0, 0xC4, 0xCC]
  @inc 0xE6
  @inc_x 0xF6
  @inc_absolute 0xEE
  @inc_absolute_x 0xFE
  @inx 0xE8
  @iny 0xC8
  @dec 0xC6
  @dec_x 0xD6
  @dec_absolute 0xCE
  @dec_absolute_x 0xDE
  @dex 0xCA
  @dey 0x88
  @asl 0x0A
  @asl_zero_page 0x06
  @asl_x 0x16
  @asl_absolute 0x0E
  @asl_absolute_x 0x1E
  @lsr 0x4A
  @lsr_zero_page 0x46
  @lsr_x 0x56
  @lsr_absolute 0x4E
  @lsr_absolute_x 0x5E
  @rol 0x2A
  @rol_zero_page 0x26
  @rol_x 0x36
  @rol_absolute 0x2E
  @rol_absolute_x 0x3E
  @ror 0x6A
  @ror_zero_page 0x66
  @ror_x 0x76
  @ror_absolute 0x6E
  @ror_absolute_x 0x7E
  @jmp 0x4C
  @jmp_indirect 0x6C
  @jsr 0x20
  @rts 0x60
  @bcc 0x90
  @bcs 0xB0
  @beq 0xF0
  @bmi 0x30
  @bne 0xD0
  @bpl 0x10
  @bvc 0x50
  @bvs 0x70
  @clc 0x18
  @cld 0xD8
  @cli 0x58
  @clv 0xB8
  @sec 0x38
  @sed 0xF8
  @sei 0x78
  @brk 0x00

  @noop_opcodes [0xEA, 0x1A, 0x3A, 0x5A, 0x7A, 0xDA, 0xFA]

  @un_noop_address_1 [
    0x04,
    0x14,
    0x34,
    0x44,
    0x54,
    0x64,
    0x74,
    0xD4,
    0xF4,
    0x80,
    0x82,
    0x89,
    0xC2,
    0xE2
  ]

  @un_noop_address_2 [0x0C, 0x1C, 0x3C, 0x5C, 0x7C, 0xDC, 0xFC]

  @lax [0xA3, 0xA7, 0xAF, 0xB3, 0xB7, 0xBF, 0xAB]
  @sax [0x83, 0x87, 0x8F, 0x97]
  @anc [0x0B, 0x2B]
  @alr 0x4B
  @arr 0x6B
  @axs 0xCB
  @shy 0x9C
  @shx 0x9E
  @rti 0x40

  # Grouped OpCodes

  @alu_opcodes @lda ++
                 @sta ++
                 @and_op ++
                 @xor_op ++
                 @or_op ++ @adc ++ @sbc ++ @cmp

  @rmw_opcodes @ldx ++ @stx

  @control_opcodes @ldy ++ @sty ++ @bit ++ @cpx ++ @cpy

  @branching_opcodes [@bcc, @bcs, @beq, @bmi, @bne, @bpl, @bvc, @bvs]

  @single_opcodes [
                    @tax,
                    @tay,
                    @txa,
                    @tya,
                    @tsx,
                    @pha,
                    @php,
                    @pla,
                    @plp,
                    @rts,
                    @clc,
                    @cld,
                    @cli,
                    @clv,
                    @sec,
                    @sed,
                    @sei,
                    @brk,
                    @rti,
                    @asl,
                    @lsr,
                    @rol,
                    @ror
                  ] ++ @noop_opcodes

  @unofficial_opcodes @lax ++
                        @sax ++
                        @anc ++
                        @dcp ++
                        @isb ++
                        @slo ++
                        @rla ++
                        @sre ++
                        @rra ++
                        [@alr, @arr, @axs, @shy, @shx]

  @zero_page_opcodes [
    @inc,
    @dec,
    @asl_zero_page,
    @lsr_zero_page,
    @rol_zero_page,
    @ror_zero_page
  ]

  @zero_page_x_opcodes [
    @inc_x,
    @dec_x,
    @asl_x,
    @lsr_x,
    @rol_x,
    @ror_x
  ]

  @absolute_opcodes [
    @inc_absolute,
    @dec_absolute,
    @asl_absolute,
    @lsr_absolute,
    @rol_absolute,
    @ror_absolute,
    @jmp,
    @jsr
  ]

  @absolute_x_opcodes [
    @inc_absolute_x,
    @dec_absolute_x,
    @asl_absolute_x,
    @lsr_absolute_x,
    @rol_absolute_x,
    @ror_absolute_x
  ]

  def execute(opcode) do
    opcode_function = fetch_opcode_function(opcode)

    case opcode_function.() do
      {:ok, status} ->
        cycles =
          case status do
            :same_page ->
              Enum.at(@cycles, opcode)

            :page_cross ->
              Enum.at(@cycles_page_cross, opcode)

            [:branched, :same_page] ->
              Enum.at(@cycles, opcode) + 1

            [:branched, :page_cross] ->
              Enum.at(@cycles_page_cross, opcode) + 1
          end

        {:ok, cycles}

      error ->
        error
    end
  end

  defp fetch_opcode_function(opcode) when opcode in @alu_opcodes do
    fn ->
      {:ok, address, status} = MOS6502.alu_address(opcode)
      :ok = alu_function(opcode).(address)
      {:ok, status}
    end
  end

  defp fetch_opcode_function(opcode) when opcode in @rmw_opcodes do
    fn ->
      {:ok, address, status} = MOS6502.rmw_address(opcode)
      :ok = rmw_function(opcode).(address)
      {:ok, status}
    end
  end

  defp fetch_opcode_function(opcode) when opcode in @control_opcodes do
    fn ->
      {:ok, address, status} = MOS6502.control_address(opcode)
      :ok = control_function(opcode).(address)
      {:ok, status}
    end
  end

  defp fetch_opcode_function(opcode) when opcode in @zero_page_opcodes do
    fn ->
      {:ok, address} = MOS6502.zero_page_address()
      :ok = zero_page_function(opcode).(address)
      {:ok, :same_page}
    end
  end

  defp fetch_opcode_function(opcode) when opcode in @zero_page_x_opcodes do
    fn ->
      {:ok, address} = MOS6502.zero_page_address(:x)
      :ok = zero_page_function(opcode).(address)
      {:ok, :same_page}
    end
  end

  defp fetch_opcode_function(opcode) when opcode in @branching_opcodes do
    fn ->
      {:ok, address, control_address_status} = MOS6502.control_address(opcode)

      case branching_function(opcode).(address) do
        {:ok, []} ->
          {:ok, control_address_status}

        status ->
          status
      end
    end
  end

  defp fetch_opcode_function(opcode) when opcode in @single_opcodes do
    fn ->
      :ok = single_function(opcode).()
      {:ok, :same_page}
    end
  end

  defp fetch_opcode_function(opcode) when opcode in @un_noop_address_1 do
    fn ->
      {:ok, address} =
        cond do
          opcode in [0x80, 0x82, 0x89, 0xC2, 0xE2] ->
            MOS6502.immediate_address()

          (opcode >>> 4 &&& 0x01) == 0 ->
            MOS6502.zero_page_address()

          true ->
            MOS6502.zero_page_address(:x)
        end

      :ok = MOS6502.noop(address)
      {:ok, :same_page}
    end
  end

  defp fetch_opcode_function(opcode) when opcode in @un_noop_address_2 do
    fn ->
      {:ok, address, status} =
        if (opcode >>> 4 &&& 0x01) == 0 do
          MOS6502.absolute_address()
        else
          MOS6502.absolute_address(:x)
        end
        |> case do
          {:ok, address} ->
            {:ok, address, :same_page}

          result ->
            result
        end

      :ok = MOS6502.noop(address)
      {:ok, status}
    end
  end

  defp fetch_opcode_function(opcode) when opcode in @unofficial_opcodes do
    fn ->
      {:ok, address, status} = MOS6502.unofficial_address(opcode)
      :ok = unofficial_function(opcode).(address)
      {:ok, status}
    end
  end

  defp fetch_opcode_function(opcode) when opcode in @absolute_opcodes do
    fn ->
      {:ok, address} = MOS6502.absolute_address()
      :ok = absolute_function(opcode).(address)
      {:ok, :same_page}
    end
  end

  defp fetch_opcode_function(opcode) when opcode in @absolute_x_opcodes do
    fn ->
      {:ok, address, status} = MOS6502.absolute_address(:x)
      :ok = absolute_function(opcode).(address)
      {:ok, status}
    end
  end

  defp fetch_opcode_function(@inx) do
    fn ->
      :ok = MOS6502.inc(:x)
      {:ok, :same_page}
    end
  end

  defp fetch_opcode_function(@iny) do
    fn ->
      :ok = MOS6502.inc(:y)
      {:ok, :same_page}
    end
  end

  defp fetch_opcode_function(@dex) do
    fn ->
      :ok = MOS6502.dec(:x)
      {:ok, :same_page}
    end
  end

  defp fetch_opcode_function(@dey) do
    fn ->
      :ok = MOS6502.dec(:y)
      {:ok, :same_page}
    end
  end

  defp fetch_opcode_function(@jmp_indirect) do
    fn ->
      {:ok, address} = MOS6502.indirect_address()
      :ok = MOS6502.jmp(address)
      {:ok, :same_page}
    end
  end

  defp fetch_opcode_function(_) do
    fn -> {:error, :invalid_opcode} end
  end

  defp absolute_function(@inc_absolute), do: &MOS6502.inc/1
  defp absolute_function(@inc_absolute_x), do: &MOS6502.inc/1
  defp absolute_function(@dec_absolute), do: &MOS6502.dec/1
  defp absolute_function(@dec_absolute_x), do: &MOS6502.dec/1
  defp absolute_function(@asl_absolute), do: &MOS6502.asl/1
  defp absolute_function(@asl_absolute_x), do: &MOS6502.asl/1
  defp absolute_function(@lsr_absolute), do: &MOS6502.lsr/1
  defp absolute_function(@lsr_absolute_x), do: &MOS6502.lsr/1
  defp absolute_function(@rol_absolute), do: &MOS6502.rol/1
  defp absolute_function(@rol_absolute_x), do: &MOS6502.rol/1
  defp absolute_function(@ror_absolute), do: &MOS6502.ror/1
  defp absolute_function(@ror_absolute_x), do: &MOS6502.ror/1
  defp absolute_function(@jmp), do: &MOS6502.jmp/1
  defp absolute_function(@jsr), do: &MOS6502.jsr/1

  defp alu_function(opcode) when opcode in @lda, do: &MOS6502.lda/1
  defp alu_function(opcode) when opcode in @sta, do: &MOS6502.sta/1
  defp alu_function(opcode) when opcode in @and_op, do: &MOS6502.and_op/1
  defp alu_function(opcode) when opcode in @xor_op, do: &MOS6502.xor_op/1
  defp alu_function(opcode) when opcode in @or_op, do: &MOS6502.or_op/1
  defp alu_function(opcode) when opcode in @adc, do: &MOS6502.adc/1
  defp alu_function(opcode) when opcode in @sbc, do: &MOS6502.sbc/1
  defp alu_function(opcode) when opcode in @cmp, do: &MOS6502.cmp/1

  defp branching_function(@bcc), do: &MOS6502.bcc/1
  defp branching_function(@bcs), do: &MOS6502.bcs/1
  defp branching_function(@beq), do: &MOS6502.beq/1
  defp branching_function(@bmi), do: &MOS6502.bmi/1
  defp branching_function(@bne), do: &MOS6502.bne/1
  defp branching_function(@bpl), do: &MOS6502.bpl/1
  defp branching_function(@bvc), do: &MOS6502.bvc/1
  defp branching_function(@bvs), do: &MOS6502.bvs/1

  defp control_function(opcode) when opcode in @ldy, do: &MOS6502.ldy/1
  defp control_function(opcode) when opcode in @sty, do: &MOS6502.sty/1
  defp control_function(opcode) when opcode in @bit, do: &MOS6502.bit/1
  defp control_function(opcode) when opcode in @cpx, do: &MOS6502.cpx/1
  defp control_function(opcode) when opcode in @cpy, do: &MOS6502.cpy/1

  defp rmw_function(opcode) when opcode in @ldx, do: &MOS6502.ldx/1
  defp rmw_function(opcode) when opcode in @stx, do: &MOS6502.stx/1

  defp single_function(@tax), do: &MOS6502.tax/0
  defp single_function(@tay), do: &MOS6502.tay/0
  defp single_function(@txa), do: &MOS6502.txa/0
  defp single_function(@tya), do: &MOS6502.tya/0
  defp single_function(@tsx), do: &MOS6502.tsx/0
  defp single_function(@pha), do: &MOS6502.pha/0
  defp single_function(@php), do: &MOS6502.php/0
  defp single_function(@pla), do: &MOS6502.pla/0
  defp single_function(@plp), do: &MOS6502.plp/0
  defp single_function(@rts), do: &MOS6502.rts/0
  defp single_function(@clc), do: &MOS6502.clc/0
  defp single_function(@cld), do: &MOS6502.cld/0
  defp single_function(@cli), do: &MOS6502.cli/0
  defp single_function(@clv), do: &MOS6502.clv/0
  defp single_function(@sec), do: &MOS6502.sec/0
  defp single_function(@sed), do: &MOS6502.sed/0
  defp single_function(@sei), do: &MOS6502.sei/0
  defp single_function(@brk), do: &MOS6502.brk/0
  defp single_function(opcode) when opcode in @noop_opcodes, do: &MOS6502.noop/0
  defp single_function(@asl), do: &MOS6502.asl/0
  defp single_function(@lsr), do: &MOS6502.lsr/0
  defp single_function(@rol), do: &MOS6502.rol/0
  defp single_function(@ror), do: &MOS6502.ror/0
  defp single_function(@rti), do: &MOS6502.rti/0

  defp unofficial_function(opcode) when opcode in @rla, do: &MOS6502.rla/1
  defp unofficial_function(opcode) when opcode in @sre, do: &MOS6502.sre/1
  defp unofficial_function(opcode) when opcode in @rra, do: &MOS6502.rra/1
  defp unofficial_function(opcode) when opcode in @isb, do: &MOS6502.isb/1
  defp unofficial_function(opcode) when opcode in @slo, do: &MOS6502.slo/1
  defp unofficial_function(opcode) when opcode in @dcp, do: &MOS6502.dcp/1
  defp unofficial_function(opcode) when opcode in @lax, do: &MOS6502.lax/1
  defp unofficial_function(opcode) when opcode in @sax, do: &MOS6502.sax/1
  defp unofficial_function(opcode) when opcode in @anc, do: &MOS6502.anc/1
  defp unofficial_function(@alr), do: &MOS6502.alr/1
  defp unofficial_function(@arr), do: &MOS6502.arr/1
  defp unofficial_function(@axs), do: &MOS6502.axs/1
  defp unofficial_function(@shy), do: &MOS6502.shy/1
  defp unofficial_function(@shx), do: &MOS6502.shx/1

  defp zero_page_function(@inc), do: &MOS6502.inc/1
  defp zero_page_function(@inc_x), do: &MOS6502.inc/1
  defp zero_page_function(@dec), do: &MOS6502.dec/1
  defp zero_page_function(@dec_x), do: &MOS6502.dec/1
  defp zero_page_function(@asl_zero_page), do: &MOS6502.asl/1
  defp zero_page_function(@asl_x), do: &MOS6502.asl/1
  defp zero_page_function(@lsr_zero_page), do: &MOS6502.lsr/1
  defp zero_page_function(@lsr_x), do: &MOS6502.lsr/1
  defp zero_page_function(@rol_zero_page), do: &MOS6502.rol/1
  defp zero_page_function(@rol_x), do: &MOS6502.rol/1
  defp zero_page_function(@ror_zero_page), do: &MOS6502.ror/1
  defp zero_page_function(@ror_x), do: &MOS6502.ror/1
end
