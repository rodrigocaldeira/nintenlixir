defmodule Nintenlixir.CPU.InstructionTest do
  use ExUnit.Case, async: true
  use Bitwise

  alias Nintenlixir.CPU.MOS6502
  alias Nintenlixir.Memory

  setup do
    start_supervised(MOS6502)
    start_supervised({Memory, MOS6502.memory_server_name()})
    :ok = MOS6502.reset()
    :ok = MOS6502.set_state(%{MOS6502.get_state() | break_error: true})
    :ok
  end

  test "invalid opcode" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0x02)
    assert {:error, {:invalid_opcode, 0}} = MOS6502.step()
  end

  test "lda_immediate" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xA9)
    write(0x0101, 0xFF)
    MOS6502.step()
    assert %{accumulator: 0xFF} = get_registers()
  end

  test "lda_zero_page" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xA5)
    write(0x0101, 0x84)
    write(0x0084, 0xFF)
    MOS6502.step()
    assert %{accumulator: 0xFF} = get_registers()
  end

  test "lda_zero_page_x" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0x01})
    write(0x0100, 0xB5)
    write(0x0101, 0x84)
    write(0x0084, 0xFF)
    MOS6502.step()
    assert %{accumulator: 0xFF} = get_registers()
  end

  test "lda_absolute" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xAD)
    write(0x0101, 0x84)
    write(0x0102, 0x84)
    write(0x0084, 0xFF)
    MOS6502.step()
    assert %{accumulator: 0xFF} = get_registers()
  end

  test "lda_absolute_x" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0x01})
    write(0x0100, 0xBD)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0084, 0xFF)
    assert {:ok, 4} = MOS6502.step()
    assert %{accumulator: 0xFF} = get_registers()

    set_registers(%{get_registers() | program_counter: 0x0100, x: 0x01})
    write(0x0100, 0xBD)
    write(0x0101, 0xFF)
    write(0x0102, 0x02)
    write(0x0300, 0xFF)
    assert {:ok, 5} = MOS6502.step()
    assert %{accumulator: 0xFF} = get_registers()
  end

  test "lda_absolute_y" do
    set_registers(%{get_registers() | program_counter: 0x0100, y: 0x01})
    write(0x0100, 0xB9)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0085, 0xFF)
    assert {:ok, 4} = MOS6502.step()
    assert %{accumulator: 0xFF} = get_registers()

    set_registers(%{get_registers() | program_counter: 0x0100, y: 0x01})
    write(0x0100, 0xB9)
    write(0x0101, 0xFF)
    write(0x0102, 0x02)
    write(0x0300, 0xFF)
    assert {:ok, 5} = MOS6502.step()
    assert %{accumulator: 0xFF} = get_registers()
  end

  test "lda_indirect_x" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0x01})
    write(0x0100, 0xA1)
    write(0x0101, 0x84)
    write(0x0085, 0x87)
    write(0x0086, 0x00)
    write(0x0087, 0xFF)
    MOS6502.step()
    assert %{accumulator: 0xFF} = get_registers()
  end

  test "lda_indirect_y" do
    set_registers(%{get_registers() | program_counter: 0x0100, y: 0x01})
    write(0x0100, 0xB1)
    write(0x0101, 0x84)
    write(0x0084, 0x86)
    write(0x0085, 0x00)
    write(0x0087, 0xFF)
    assert {:ok, 5} = MOS6502.step()
    assert %{accumulator: 0xFF} = get_registers()
    set_registers(%{get_registers() | program_counter: 0x0100, y: 0x01})
    write(0x0100, 0xB1)
    write(0x0101, 0x84)
    write(0x0084, 0xFF)
    write(0x0085, 0x02)
    write(0x0300, 0xFF)
    assert {:ok, 6} = MOS6502.step()
    assert %{accumulator: 0xFF} = get_registers()
  end

  test "lda_z_flag_set" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xA9)
    write(0x0101, 0x00)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "lda_z_flag_unset" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xA9)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "lda_n_flag_set" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xA9)
    write(0x0101, 0x81)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "lda_n_flag_unset" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xA9)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "ldx_immediate" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xA2)
    write(0x0101, 0xFF)
    MOS6502.step()
    assert %{x: 0xFF} = get_registers()
  end

  test "ldx_zero_page" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xA6)
    write(0x0101, 0x84)
    write(0x0084, 0xFF)
    MOS6502.step()
    assert %{x: 0xFF} = get_registers()
  end

  test "ldx_zero_page_y" do
    set_registers(%{get_registers() | program_counter: 0x0100, y: 0x01})
    write(0x0100, 0xB6)
    write(0x0101, 0x84)
    write(0x0085, 0xFF)
    MOS6502.step()
    assert %{x: 0xFF} = get_registers()
  end

  test "ldx_absolute" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xAE)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0084, 0xFF)
    MOS6502.step()
    assert %{x: 0xFF} = get_registers()
  end

  test "ldx_absolute_y" do
    set_registers(%{get_registers() | program_counter: 0x0100, y: 0x01})
    write(0x0100, 0xBE)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0085, 0xFF)
    MOS6502.step()
    assert %{x: 0xFF} = get_registers()
  end

  test "ldx_z_flag_set" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xA2)
    write(0x0101, 0x00)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "ldx_z_flag_unset" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xA2)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "ldx_n_flag_set" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xA2)
    write(0x0101, 0x81)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "ldx_n_flag_unset" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xA2)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "ldy_immediate" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xA0)
    write(0x0101, 0xFF)
    MOS6502.step()
    assert %{y: 0xFF} = get_registers()
  end

  test "ldy_zero_page" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xA4)
    write(0x0101, 0x84)
    write(0x0084, 0xFF)
    MOS6502.step()
    assert %{y: 0xFF} = get_registers()
  end

  test "ldy_zero_page_x" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0x01})
    write(0x0100, 0xB4)
    write(0x0101, 0x84)
    write(0x0085, 0xFF)
    MOS6502.step()
    assert %{y: 0xFF} = get_registers()
  end

  test "ldy_absolute" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xAC)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0084, 0xFF)
    MOS6502.step()
    assert %{y: 0xFF} = get_registers()
  end

  test "ldy_absolute_x" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0x01})
    write(0x0100, 0xBC)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0085, 0xFF)
    MOS6502.step()
    assert %{y: 0xFF} = get_registers()
  end

  test "ldy_z_flag_set" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xA0)
    write(0x0101, 0x00)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "ldy_z_flag_unset" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xA0)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "ldy_n_flag_set" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xA2)
    write(0x0101, 0x81)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "ldy_n_flag_unset" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xA2)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "sta_zero_page" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF})
    write(0x0100, 0x85)
    write(0x0101, 0x84)
    MOS6502.step()
    assert {:ok, 0xFF} = read(0x0084)
  end

  test "sta_zero_page_x" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF, x: 0x01})
    write(0x0100, 0x95)
    write(0x0101, 0x84)
    MOS6502.step()
    assert {:ok, 0xFF} = read(0x0085)
  end

  test "sta_absolute" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF})
    write(0x0100, 0x8D)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    MOS6502.step()
    assert {:ok, 0xFF} = read(0x0084)
  end

  test "sta_absolute_x" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF, x: 0x01})
    write(0x0100, 0x9D)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    MOS6502.step()
    assert {:ok, 0xFF} = read(0x0085)
  end

  test "sta_absolute_y" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF, y: 0x01})
    write(0x0100, 0x99)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    MOS6502.step()
    assert {:ok, 0xFF} = read(0x0085)
  end

  test "sta_indirect_x" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF, x: 0x01})
    write(0x0100, 0x81)
    write(0x0101, 0x84)
    write(0x0085, 0x87)
    write(0x0086, 0x00)
    MOS6502.step()
    assert {:ok, 0xFF} = read(0x0087)
  end

  test "sta_indirect_y" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF, y: 0x01})
    write(0x0100, 0x91)
    write(0x0101, 0x84)
    write(0x0084, 0x86)
    write(0x0085, 0x00)
    MOS6502.step()
    assert {:ok, 0xFF} = read(0x0087)
  end

  test "stx_zero_page" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0xFF})
    write(0x0100, 0x86)
    write(0x0101, 0x84)
    MOS6502.step()
    assert {:ok, 0xFF} = read(0x0084)
  end

  test "stx_zero_page_y" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0xFF, y: 0x01})
    write(0x0100, 0x96)
    write(0x0101, 0x84)
    MOS6502.step()
    assert {:ok, 0xFF} = read(0x0085)
  end

  test "stx_absolute" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0xFF})
    write(0x0100, 0x8E)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    MOS6502.step()
    assert {:ok, 0xFF} = read(0x0084)
  end

  test "sty_zero_page" do
    set_registers(%{get_registers() | program_counter: 0x0100, y: 0xFF})
    write(0x0100, 0x84)
    write(0x0101, 0x84)
    MOS6502.step()
    assert {:ok, 0xFF} = read(0x0084)
  end

  test "sty_zero_page_y" do
    set_registers(%{get_registers() | program_counter: 0x0100, y: 0xFF, x: 0x01})
    write(0x0100, 0x94)
    write(0x0101, 0x84)
    MOS6502.step()
    assert {:ok, 0xFF} = read(0x0085)
  end

  test "sty_absolute" do
    set_registers(%{get_registers() | program_counter: 0x0100, y: 0xFF})
    write(0x0100, 0x8C)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    MOS6502.step()
    assert {:ok, 0xFF} = read(0x0084)
  end

  test "tax" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF})
    write(0x0100, 0xAA)
    MOS6502.step()
    assert %{x: 0xFF} = get_registers()
  end

  test "tax_z_flag_set" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x00})
    write(0x0100, 0xAA)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "tax_z_flag_unset" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x01})
    write(0x0100, 0xAA)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "tax_n_flag_set" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x81})
    write(0x0100, 0xAA)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "tax_n_flag_unset" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x01})
    write(0x0100, 0xAA)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "tay" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF})
    write(0x0100, 0xA8)
    MOS6502.step()
    assert %{y: 0xFF} = get_registers()
  end

  test "txa" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0xFF})
    write(0x0100, 0x8A)
    MOS6502.step()
    assert %{accumulator: 0xFF} = get_registers()
  end

  test "tya" do
    set_registers(%{get_registers() | program_counter: 0x0100, y: 0xFF})
    write(0x0100, 0x98)
    MOS6502.step()
    assert %{accumulator: 0xFF} = get_registers()
  end

  test "tsx" do
    set_registers(%{get_registers() | program_counter: 0x0100, stack_pointer: 0xFF})
    write(0x0100, 0xBA)
    MOS6502.step()
    assert %{x: 0xFF} = get_registers()
  end

  test "txs" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0xFF})
    write(0x0100, 0x9A)
    MOS6502.step()
    assert %{stack_pointer: 0xFF} = get_registers()
  end

  test "pha" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF})
    write(0x0100, 0x48)
    MOS6502.step()
    assert {:ok, 0xFF} = MOS6502.pop()
  end

  test "php" do
    set_registers(%{get_registers() | program_counter: 0x0100, processor_status: 0xFF})
    write(0x0100, 0x08)
    MOS6502.step()
    assert {:ok, 0xFF} = MOS6502.pop()
  end

  test "pla" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    MOS6502.push(0xFE)
    write(0x0100, 0x68)
    MOS6502.step()
    assert %{accumulator: 0xFE} = get_registers()
  end

  test "pla_z_flag_set" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    MOS6502.push(0x00)
    write(0x0100, 0x68)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "pla_z_flag_unset" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    MOS6502.push(0x01)
    write(0x0100, 0x68)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "pla_n_flag_set" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    MOS6502.push(0x81)
    write(0x0100, 0x68)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "pla_n_flag_unset" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    MOS6502.push(0x01)
    write(0x0100, 0x68)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "plp" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    MOS6502.push(0xFF)
    write(0x0100, 0x28)
    MOS6502.step()
    assert %{processor_status: 0xCF} = get_registers()
  end

  test "and immediate" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF})
    write(0x0100, 0x29)
    write(0x0101, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0x0F} = get_registers()
  end

  test "and zero page" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF})
    write(0x0100, 0x25)
    write(0x0101, 0x84)
    write(0x0084, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0x0F} = get_registers()
  end

  test "and zero page x" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF, x: 0x01})
    write(0x0100, 0x35)
    write(0x0101, 0x84)
    write(0x0085, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0x0F} = get_registers()
  end

  test "and absolute" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF})
    write(0x0100, 0x2D)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0084, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0x0F} = get_registers()
  end

  test "and absolute x" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF, x: 0x01})
    write(0x0100, 0x3D)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0085, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0x0F} = get_registers()
  end

  test "and indirect x" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF, x: 0x01})
    write(0x0100, 0x21)
    write(0x0101, 0x84)
    write(0x0085, 0x87)
    write(0x0086, 0x00)
    write(0x0087, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0x0F} = get_registers()
  end

  test "and indirect y" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF, y: 0x01})
    write(0x0100, 0x31)
    write(0x0101, 0x84)
    write(0x0084, 0x86)
    write(0x0085, 0x00)
    write(0x0087, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0x0F} = get_registers()
  end

  test "and_z_flag_set" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0x29)
    write(0x0101, 0x00)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "and_z_flag_unset" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x01})
    write(0x0100, 0x29)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "and_n_flag_set" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x81})
    write(0x0100, 0x29)
    write(0x0101, 0x81)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "and_n_flag_unset" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0x29)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "eor immediate" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF})
    write(0x0100, 0x49)
    write(0x0101, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0xF0} = get_registers()
  end

  test "eor zero page" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF})
    write(0x0100, 0x45)
    write(0x0101, 0x84)
    write(0x0084, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0xF0} = get_registers()
  end

  test "eor zero page x" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF, x: 0x01})
    write(0x0100, 0x55)
    write(0x0101, 0x84)
    write(0x0085, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0xF0} = get_registers()
  end

  test "eor absolute" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF})
    write(0x0100, 0x4D)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0084, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0xF0} = get_registers()
  end

  test "eor absolute x" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF, x: 0x01})
    write(0x0100, 0x5D)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0085, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0xF0} = get_registers()
  end

  test "eor absolute y" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF, y: 0x01})
    write(0x0100, 0x59)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0085, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0xF0} = get_registers()
  end

  test "eor indirect x" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF, x: 0x01})
    write(0x0100, 0x41)
    write(0x0101, 0x84)
    write(0x0085, 0x87)
    write(0x0086, 0x00)
    write(0x0087, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0xF0} = get_registers()
  end

  test "eor indirect y" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF, y: 0x01})
    write(0x0100, 0x51)
    write(0x0101, 0x84)
    write(0x0084, 0x86)
    write(0x0085, 0x00)
    write(0x0087, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0xF0} = get_registers()
  end

  test "eor_z_flag_set" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0x49)
    write(0x0101, 0x00)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "eor_z_flag_unset" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x00})
    write(0x0100, 0x49)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "eor_n_flag_set" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x00})
    write(0x0100, 0x49)
    write(0x0101, 0x81)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "eor_n_flag_unset" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0x49)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "ora immediate" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xF0})
    write(0x0100, 0x09)
    write(0x0101, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0xFF} = get_registers()
  end

  test "ora zero page" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xF0})
    write(0x0100, 0x05)
    write(0x0101, 0x84)
    write(0x0084, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0xFF} = get_registers()
  end

  test "ora zero page x" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xF0, x: 0x01})
    write(0x0100, 0x15)
    write(0x0101, 0x84)
    write(0x0085, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0xFF} = get_registers()
  end

  test "ora absolute" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xF0})
    write(0x0100, 0x0D)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0084, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0xFF} = get_registers()
  end

  test "ora absolute x" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xF0, x: 0x01})
    write(0x0100, 0x1D)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0085, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0xFF} = get_registers()
  end

  test "ora absolute y" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xF0, y: 0x01})
    write(0x0100, 0x19)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0085, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0xFF} = get_registers()
  end

  test "ora indirect x" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xF0, x: 0x01})
    write(0x0100, 0x01)
    write(0x0101, 0x84)
    write(0x0085, 0x87)
    write(0x0086, 0x00)
    write(0x0087, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0xFF} = get_registers()
  end

  test "ora indirect y" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xF0, y: 0x01})
    write(0x0100, 0x11)
    write(0x0101, 0x84)
    write(0x0084, 0x86)
    write(0x0085, 0x00)
    write(0x0087, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0xFF} = get_registers()
  end

  test "ora_z_flag_set" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0x09)
    write(0x0101, 0x00)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "ora_z_flag_unset" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x01})
    write(0x0100, 0x09)
    write(0x0101, 0x00)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "ora_n_flag_set" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x81})
    write(0x0100, 0x09)
    write(0x0101, 0x00)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "ora_n_flag_unset" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0x49)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "bit zero page" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF})
    write(0x0100, 0x24)
    write(0x0101, 0x84)
    write(0x0084, 0x7F)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "bit absolute" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF})
    write(0x0100, 0x2C)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0084, 0x7F)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "bit set n flag" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF})
    write(0x0100, 0x24)
    write(0x0101, 0x84)
    write(0x0084, 0xFF)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "bit unset n flag" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF})
    write(0x0100, 0x24)
    write(0x0101, 0x84)
    write(0x0084, 0x7F)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "bit set v flag" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF})
    write(0x0100, 0x24)
    write(0x0101, 0x84)
    write(0x0084, 0xFF)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 64) == 0
  end

  test "bit unset v flag" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF})
    write(0x0100, 0x24)
    write(0x0101, 0x84)
    write(0x0084, 0x3F)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 64) == 0
  end

  test "bit set z flag" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x00})
    write(0x0100, 0x24)
    write(0x0101, 0x84)
    write(0x0084, 0xFF)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "bit unset z flag" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF})
    write(0x0100, 0x24)
    write(0x0101, 0x84)
    write(0x0084, 0x3F)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "adc immediate" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x01})
    write(0x0100, 0x69)
    write(0x0101, 0x02)
    MOS6502.step()
    assert %{accumulator: 0x03, processor_status: processor_status} = get_registers()
    processor_status = processor_status ||| 8

    set_registers(%{
      get_registers()
      | processor_status: processor_status,
        program_counter: 0x0100,
        accumulator: 0x29
    })

    write(0x0100, 0x69)
    write(0x0101, 0x11)
    MOS6502.step()
    assert %{accumulator: 0x40, processor_status: processor_status} = get_registers()
    processor_status = processor_status ||| 8

    set_registers(%{
      get_registers()
      | processor_status: processor_status,
        program_counter: 0x0100,
        accumulator: 0x29 ||| (128 &&& 0x00FF)
    })

    write(0x0100, 0x69)
    write(0x0101, 0x29)
    MOS6502.step()
    assert %{accumulator: 0x38, processor_status: processor_status} = get_registers()
    processor_status = processor_status ||| 8
    processor_status = processor_status ||| 1

    set_registers(%{
      get_registers()
      | processor_status: processor_status,
        program_counter: 0x0100,
        accumulator: 0x58
    })

    write(0x0100, 0x69)
    write(0x0101, 0x46)
    MOS6502.step()
    assert %{accumulator: 0x05} = get_registers()
  end

  test "adc zero page" do
    set_registers(%{get_registers() | accumulator: 0x01, program_counter: 0x0100})
    write(0x0100, 0x65)
    write(0x0101, 0x84)
    write(0x0084, 0x02)
    MOS6502.step()
    assert %{accumulator: 0x03} = get_registers()
  end

  test "adc zero page x" do
    set_registers(%{get_registers() | accumulator: 0x01, program_counter: 0x0100, x: 0x01})
    write(0x0100, 0x75)
    write(0x0101, 0x84)
    write(0x0085, 0x02)
    MOS6502.step()
    assert %{accumulator: 0x03} = get_registers()
  end

  test "adc absolute" do
    set_registers(%{get_registers() | accumulator: 0x01, program_counter: 0x0100})
    write(0x0100, 0x6D)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0084, 0x02)
    MOS6502.step()
    assert %{accumulator: 0x03} = get_registers()
  end

  test "adc absolute x" do
    set_registers(%{get_registers() | accumulator: 0x01, program_counter: 0x0100, x: 0x01})
    write(0x0100, 0x7D)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0085, 0x02)
    MOS6502.step()
    assert %{accumulator: 0x03} = get_registers()
  end

  test "adc absolute y" do
    set_registers(%{get_registers() | accumulator: 0x01, program_counter: 0x0100, y: 0x01})
    write(0x0100, 0x79)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0085, 0x02)
    MOS6502.step()
    assert %{accumulator: 0x03} = get_registers()
  end

  test "adc indirect x" do
    set_registers(%{get_registers() | accumulator: 0x01, program_counter: 0x0100, x: 0x01})
    write(0x0100, 0x61)
    write(0x0101, 0x84)
    write(0x0085, 0x87)
    write(0x0086, 0x00)
    write(0x0087, 0x02)
    MOS6502.step()
    assert %{accumulator: 0x03} = get_registers()
  end

  test "adc indirect y" do
    set_registers(%{get_registers() | accumulator: 0x01, program_counter: 0x0100, y: 0x01})
    write(0x0100, 0x71)
    write(0x0101, 0x84)
    write(0x0084, 0x86)
    write(0x0085, 0x00)
    write(0x0087, 0x02)
    MOS6502.step()
    assert %{accumulator: 0x03} = get_registers()
  end

  test "adc c flag set" do
    set_registers(%{get_registers() | accumulator: 0xFF, program_counter: 0x0100})
    write(0x0100, 0x69)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 1) == 0
    processor_status = processor_status ||| 1

    set_registers(%{
      get_registers()
      | accumulator: 0xFF,
        program_counter: 0x0100,
        processor_status: processor_status
    })

    write(0x0100, 0x69)
    write(0x0101, 0x00)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 1) == 0
  end

  test "adc c flag unset" do
    set_registers(%{get_registers() | accumulator: 0x00, program_counter: 0x0100})
    write(0x0100, 0x69)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 1) == 0
    processor_status = processor_status &&& ~~~1

    set_registers(%{
      get_registers()
      | accumulator: 0x00,
        program_counter: 0x0100,
        processor_status: processor_status
    })

    write(0x0100, 0x69)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 1) == 0
  end

  test "adc z flag set" do
    set_registers(%{get_registers() | accumulator: 0x00, program_counter: 0x0100})
    write(0x0100, 0x69)
    write(0x0101, 0x00)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
    processor_status = processor_status ||| 1

    set_registers(%{
      get_registers()
      | accumulator: 0xFE,
        program_counter: 0x0100,
        processor_status: processor_status
    })

    write(0x0100, 0x69)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 1) == 0
  end

  test "adc z flag unset" do
    set_registers(%{get_registers() | accumulator: 0x00, program_counter: 0x0100})
    write(0x0100, 0x69)
    write(0x0101, 0xFF)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
    set_registers(%{get_registers() | accumulator: 0xFE, program_counter: 0x0100})
    write(0x0100, 0x69)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 1) == 0
  end

  test "adc v flag set" do
    set_registers(%{get_registers() | accumulator: 0x7F, program_counter: 0x0100})
    write(0x0100, 0x69)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 64) == 0
  end

  test "adc v flag unset" do
    set_registers(%{get_registers() | accumulator: 0x01, program_counter: 0x0100})
    write(0x0100, 0x69)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 64) == 0
  end

  test "adc n flag set" do
    set_registers(%{get_registers() | accumulator: 0x01, program_counter: 0x0100})
    write(0x0100, 0x69)
    write(0x0101, 0xFE)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "adc n flag unset" do
    set_registers(%{get_registers() | accumulator: 0x01, program_counter: 0x0100})
    write(0x0100, 0x69)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "sbc immediate" do
    %{processor_status: processor_status} = get_registers()

    set_registers(%{
      get_registers()
      | accumulator: 0x02,
        program_counter: 0x0100,
        processor_status: processor_status ||| 1
    })

    write(0x0100, 0xE9)
    write(0x0101, 0x01)
    MOS6502.step()
    assert %{accumulator: 0x01, processor_status: processor_status} = get_registers()
    processor_status = processor_status ||| 8

    set_registers(%{
      get_registers()
      | accumulator: 0x29,
        program_counter: 0x0100,
        processor_status: processor_status
    })

    write(0x0100, 0xE9)
    write(0x0101, 0x11)
    MOS6502.step()
    assert %{accumulator: 0x18} = get_registers()
  end

  test "sbc zero page" do
    %{processor_status: processor_status} = get_registers()

    set_registers(%{
      get_registers()
      | accumulator: 0x02,
        program_counter: 0x0100,
        processor_status: processor_status ||| 1
    })

    write(0x0100, 0xE5)
    write(0x0101, 0x84)
    write(0x0084, 0x01)
    MOS6502.step()
    assert %{accumulator: 0x01} = get_registers()
  end

  test "sbc zero page x" do
    %{processor_status: processor_status} = get_registers()

    set_registers(%{
      get_registers()
      | accumulator: 0x02,
        program_counter: 0x0100,
        processor_status: processor_status ||| 1,
        x: 0x01
    })

    write(0x0100, 0xF5)
    write(0x0101, 0x84)
    write(0x0085, 0x01)
    MOS6502.step()
    assert %{accumulator: 0x01} = get_registers()
  end

  test "sbc absolute" do
    %{processor_status: processor_status} = get_registers()

    set_registers(%{
      get_registers()
      | accumulator: 0x02,
        program_counter: 0x0100,
        processor_status: processor_status ||| 1
    })

    write(0x0100, 0xED)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0084, 0x01)
    MOS6502.step()
    assert %{accumulator: 0x01} = get_registers()
  end

  test "sbc absolute x" do
    %{processor_status: processor_status} = get_registers()

    set_registers(%{
      get_registers()
      | accumulator: 0x02,
        program_counter: 0x0100,
        processor_status: processor_status ||| 1,
        x: 0x01
    })

    write(0x0100, 0xFD)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0085, 0x01)
    MOS6502.step()
    assert %{accumulator: 0x01} = get_registers()
  end

  test "sbc absolute y" do
    %{processor_status: processor_status} = get_registers()

    set_registers(%{
      get_registers()
      | accumulator: 0x02,
        program_counter: 0x0100,
        processor_status: processor_status ||| 1,
        y: 0x01
    })

    write(0x0100, 0xF9)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0085, 0x01)
    MOS6502.step()
    assert %{accumulator: 0x01} = get_registers()
  end

  test "sbc indirect x" do
    %{processor_status: processor_status} = get_registers()

    set_registers(%{
      get_registers()
      | accumulator: 0x02,
        program_counter: 0x0100,
        processor_status: processor_status ||| 1,
        x: 0x01
    })

    write(0x0100, 0xE1)
    write(0x0101, 0x84)
    write(0x0085, 0x87)
    write(0x0086, 0x00)
    write(0x0087, 0x01)
    MOS6502.step()
    assert %{accumulator: 0x01} = get_registers()
  end

  test "sbc indirect y" do
    %{processor_status: processor_status} = get_registers()

    set_registers(%{
      get_registers()
      | accumulator: 0x02,
        program_counter: 0x0100,
        processor_status: processor_status ||| 1,
        y: 0x01
    })

    write(0x0100, 0xF1)
    write(0x0101, 0x84)
    write(0x0084, 0x86)
    write(0x0085, 0x00)
    write(0x0087, 0x01)
    MOS6502.step()
    assert %{accumulator: 0x01} = get_registers()
  end

  test "sbc c flag set" do
    set_registers(%{get_registers() | accumulator: 0xC4, program_counter: 0x0100})
    write(0x0100, 0xE9)
    write(0x0101, 0x3C)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 1) == 0
  end

  test "sbc c flag unset" do
    set_registers(%{get_registers() | accumulator: 0x02, program_counter: 0x0100})
    write(0x0100, 0xE9)
    write(0x0101, 0x04)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 1) == 0
  end

  test "sbc z flag set" do
    set_registers(%{get_registers() | accumulator: 0x02, program_counter: 0x0100})
    write(0x0100, 0xE9)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "sbc z flag unset" do
    set_registers(%{get_registers() | accumulator: 0x02, program_counter: 0x0100})
    write(0x0100, 0xE9)
    write(0x0101, 0x02)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "sbc v flag set" do
    set_registers(%{get_registers() | accumulator: 0x80, program_counter: 0x0100})
    write(0x0100, 0xE9)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 64) == 0
  end

  test "sbc v flag unset" do
    set_registers(%{get_registers() | accumulator: 0x01, program_counter: 0x0100})
    write(0x0100, 0xE9)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 64) == 0
  end

  test "sbc n flag set" do
    set_registers(%{get_registers() | accumulator: 0xFD, program_counter: 0x0100})
    write(0x0100, 0xE9)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "sbc n flag unset" do
    set_registers(%{get_registers() | accumulator: 0x02, program_counter: 0x0100})
    write(0x0100, 0xE9)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "cmp immediate" do
    set_registers(%{get_registers() | accumulator: 0xFF, program_counter: 0x0100})
    write(0x0100, 0xC9)
    write(0x0101, 0xFF)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "cmp zero page" do
    set_registers(%{get_registers() | accumulator: 0xFF, program_counter: 0x0100})
    write(0x0100, 0xC5)
    write(0x0101, 0x84)
    write(0x0084, 0xFF)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "cmp zero page x" do
    set_registers(%{get_registers() | accumulator: 0xFF, program_counter: 0x0100, x: 0x01})
    write(0x0100, 0xC5)
    write(0x0101, 0x84)
    write(0x0085, 0xFF)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "cmp absolute" do
    set_registers(%{get_registers() | accumulator: 0xFF, program_counter: 0x0100})
    write(0x0100, 0xCD)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0084, 0xFF)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "cmp absolute x" do
    set_registers(%{get_registers() | accumulator: 0xFF, program_counter: 0x0100, x: 0x01})
    write(0x0100, 0xDD)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0085, 0xFF)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "cmp absolute y" do
    set_registers(%{get_registers() | accumulator: 0xFF, program_counter: 0x0100, y: 0x01})
    write(0x0100, 0xD9)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0085, 0xFF)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "cmp indirect x" do
    set_registers(%{get_registers() | accumulator: 0xFF, program_counter: 0x0100, x: 0x01})
    write(0x0100, 0xC1)
    write(0x0101, 0x84)
    write(0x0085, 0x87)
    write(0x0086, 0x00)
    write(0x0087, 0xFF)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "cmp indirect y" do
    set_registers(%{get_registers() | accumulator: 0xFF, program_counter: 0x0100, y: 0x01})
    write(0x0100, 0xD1)
    write(0x0101, 0x84)
    write(0x0084, 0x86)
    write(0x0085, 0x00)
    write(0x0087, 0xFF)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "cmp n flag set" do
    set_registers(%{get_registers() | accumulator: 0x01, program_counter: 0x0100})
    write(0x0100, 0xC9)
    write(0x0101, 0x02)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "cmp n flag unset" do
    set_registers(%{get_registers() | accumulator: 0x01, program_counter: 0x0100})
    write(0x0100, 0xC9)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "cmp z flag set" do
    set_registers(%{get_registers() | accumulator: 0x02, program_counter: 0x0100})
    write(0x0100, 0xC9)
    write(0x0101, 0x02)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
    set_registers(%{get_registers() | accumulator: 0xFE, program_counter: 0x0100})
    write(0x0100, 0xC9)
    write(0x0101, 0xFE)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "cmp z flag unset" do
    set_registers(%{get_registers() | accumulator: 0x02, program_counter: 0x0100})
    write(0x0100, 0xC9)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
    set_registers(%{get_registers() | accumulator: 0xFE, program_counter: 0x0100})
    write(0x0100, 0xC9)
    write(0x0101, 0xFF)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "cmp c flag set" do
    set_registers(%{get_registers() | accumulator: 0x01, program_counter: 0x0100})
    write(0x0100, 0xC9)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 1) == 0
    set_registers(%{get_registers() | accumulator: 0x02, program_counter: 0x0100})
    write(0x0100, 0xC9)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 1) == 0
    set_registers(%{get_registers() | accumulator: 0xFE, program_counter: 0x0100})
    write(0x0100, 0xC9)
    write(0x0101, 0xFD)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 1) == 0
  end

  test "cmp c flag unset" do
    set_registers(%{get_registers() | accumulator: 0x01, program_counter: 0x0100})
    write(0x0100, 0xC9)
    write(0x0101, 0x02)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 1) == 0
    set_registers(%{get_registers() | accumulator: 0xFD, program_counter: 0x0100})
    write(0x0100, 0xC9)
    write(0x0101, 0xFE)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 1) == 0
  end

  test "cpx immediate" do
    set_registers(%{get_registers() | x: 0xFF, program_counter: 0x0100})
    write(0x0100, 0xE0)
    write(0x0101, 0xFF)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "cpx zero page" do
    set_registers(%{get_registers() | x: 0xFF, program_counter: 0x0100})
    write(0x0100, 0xE4)
    write(0x0101, 0x84)
    write(0x0084, 0xFF)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "cpx absolute" do
    set_registers(%{get_registers() | x: 0xFF, program_counter: 0x0100})
    write(0x0100, 0xEC)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0084, 0xFF)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "cpx n flag set" do
    set_registers(%{get_registers() | x: 0x01, program_counter: 0x0100})
    write(0x0100, 0xE0)
    write(0x0101, 0x02)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "cpx n flag unset" do
    set_registers(%{get_registers() | x: 0x01, program_counter: 0x0100})
    write(0x0100, 0xE0)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "cpx z flag set" do
    set_registers(%{get_registers() | x: 0x02, program_counter: 0x0100})
    write(0x0100, 0xE0)
    write(0x0101, 0x02)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "cpx z flag unset" do
    set_registers(%{get_registers() | x: 0x02, program_counter: 0x0100})
    write(0x0100, 0xE0)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "cpx c flag set" do
    set_registers(%{get_registers() | x: 0x01, program_counter: 0x0100})
    write(0x0100, 0xE0)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 1) == 0
  end

  test "cpx c flag unset" do
    set_registers(%{get_registers() | x: 0x01, program_counter: 0x0100})
    write(0x0100, 0xE0)
    write(0x0101, 0x02)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 1) == 0
  end

  test "cpy immediate" do
    set_registers(%{get_registers() | y: 0xFF, program_counter: 0x0100})
    write(0x0100, 0xC0)
    write(0x0101, 0xFF)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "cpy zero page" do
    set_registers(%{get_registers() | y: 0xFF, program_counter: 0x0100})
    write(0x0100, 0xC4)
    write(0x0101, 0x84)
    write(0x0084, 0xFF)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "cpy absolute" do
    set_registers(%{get_registers() | y: 0xFF, program_counter: 0x0100})
    write(0x0100, 0xCC)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0084, 0xFF)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "cpy n flag set" do
    set_registers(%{get_registers() | y: 0x01, program_counter: 0x0100})
    write(0x0100, 0xC0)
    write(0x0101, 0x02)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "cpy n flag unset" do
    set_registers(%{get_registers() | y: 0x01, program_counter: 0x0100})
    write(0x0100, 0xC0)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "cpy z flag set" do
    set_registers(%{get_registers() | y: 0x02, program_counter: 0x0100})
    write(0x0100, 0xC0)
    write(0x0101, 0x02)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "cpy z flag unset" do
    set_registers(%{get_registers() | y: 0x02, program_counter: 0x0100})
    write(0x0100, 0xC0)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "cpy c flag set" do
    set_registers(%{get_registers() | y: 0x01, program_counter: 0x0100})
    write(0x0100, 0xC0)
    write(0x0101, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 1) == 0
  end

  test "cpy c flag unset" do
    set_registers(%{get_registers() | y: 0x01, program_counter: 0x0100})
    write(0x0100, 0xC0)
    write(0x0101, 0x02)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 1) == 0
  end

  test "inc zero page" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xE6)
    write(0x0101, 0x84)
    write(0x0084, 0xFE)
    MOS6502.step()
    assert {:ok, 0xFF} = read(0x0084)
  end

  test "inc zero page x" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0x01})
    write(0x0100, 0xF6)
    write(0x0101, 0x84)
    write(0x0085, 0xFE)
    MOS6502.step()
    assert {:ok, 0xFF} = read(0x0085)
  end

  test "inc absolute" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xEE)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0084, 0xFE)
    MOS6502.step()
    assert {:ok, 0xFF} = read(0x0084)
  end

  test "inc absolute x" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0x01})
    write(0x0100, 0xFE)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0085, 0xFE)
    MOS6502.step()
    assert {:ok, 0xFF} = read(0x0085)
  end

  test "inc z flag set" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xE6)
    write(0x0101, 0x84)
    write(0x0084, 0xFF)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "inc z flag unset" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xE6)
    write(0x0101, 0x84)
    write(0x0084, 0x00)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "inc n flag set" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xE6)
    write(0x0101, 0x84)
    write(0x0084, 0xFE)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "inc n flag unset" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xE6)
    write(0x0101, 0x84)
    write(0x0084, 0x00)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "inx" do
    set_registers(%{get_registers() | x: 0xFE, program_counter: 0x0100})
    write(0x0100, 0xE8)
    MOS6502.step()
    assert %{x: 0xFF} = get_registers()
  end

  test "inx z flag set" do
    set_registers(%{get_registers() | x: 0xFF, program_counter: 0x0100})
    write(0x0100, 0xE8)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "inx z flag unset" do
    set_registers(%{get_registers() | x: 0x01, program_counter: 0x0100})
    write(0x0100, 0xE8)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "inx n flag set" do
    set_registers(%{get_registers() | x: 0xFE, program_counter: 0x0100})
    write(0x0100, 0xE8)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "inx n flag unset" do
    set_registers(%{get_registers() | x: 0x01, program_counter: 0x0100})
    write(0x0100, 0xE8)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "iny" do
    set_registers(%{get_registers() | y: 0xFE, program_counter: 0x0100})
    write(0x0100, 0xC8)
    MOS6502.step()
    assert %{y: 0xFF} = get_registers()
  end

  test "iny z flag set" do
    set_registers(%{get_registers() | y: 0xFF, program_counter: 0x0100})
    write(0x0100, 0xC8)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "iny z flag unset" do
    set_registers(%{get_registers() | y: 0x01, program_counter: 0x0100})
    write(0x0100, 0xC8)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "iny n flag set" do
    set_registers(%{get_registers() | y: 0xFE, program_counter: 0x0100})
    write(0x0100, 0xC8)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "iny n flag unset" do
    set_registers(%{get_registers() | y: 0x01, program_counter: 0x0100})
    write(0x0100, 0xC8)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "dec zero page" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xC6)
    write(0x0101, 0x84)
    write(0x0084, 0x02)
    MOS6502.step()
    assert {:ok, 0x01} = read(0x0084)
  end

  test "dec zero page x" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0x01})
    write(0x0100, 0xD6)
    write(0x0101, 0x84)
    write(0x0085, 0x02)
    MOS6502.step()
    assert {:ok, 0x01} = read(0x0085)
  end

  test "dec absolute" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xCE)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0084, 0x02)
    MOS6502.step()
    assert {:ok, 0x01} = read(0x0084)
  end

  test "dec absolute x" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0x01})
    write(0x0100, 0xDE)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0085, 0x02)
    MOS6502.step()
    assert {:ok, 0x01} = read(0x0085)
  end

  test "dec z flag set" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xC6)
    write(0x0101, 0x84)
    write(0x0084, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "dec z flag unset" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xC6)
    write(0x0101, 0x84)
    write(0x0084, 0x02)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "dec n flag set" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xC6)
    write(0x0101, 0x84)
    write(0x0084, 0x00)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "dec n flag unset" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0xC6)
    write(0x0101, 0x84)
    write(0x0084, 0x01)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "dex" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0x02})
    write(0x0100, 0xCA)
    MOS6502.step()
    assert %{x: 0x01} = get_registers()
  end

  test "dex z flag set" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0x01})
    write(0x0100, 0xCA)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "dex z flag unset" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0x02})
    write(0x0100, 0xCA)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "dex n flag set" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0x00})
    write(0x0100, 0xCA)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "dex n flag unset" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0x01})
    write(0x0100, 0xCA)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "dey" do
    set_registers(%{get_registers() | program_counter: 0x0100, y: 0x02})
    write(0x0100, 0x88)
    MOS6502.step()
    assert %{y: 0x01} = get_registers()
  end

  test "dey z flag set" do
    set_registers(%{get_registers() | program_counter: 0x0100, y: 0x01})
    write(0x0100, 0x88)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "dey z flag unset" do
    set_registers(%{get_registers() | program_counter: 0x0100, y: 0x02})
    write(0x0100, 0x88)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "dey n flag set" do
    set_registers(%{get_registers() | program_counter: 0x0100, y: 0x00})
    write(0x0100, 0x88)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "dey n flag unset" do
    set_registers(%{get_registers() | program_counter: 0x0100, y: 0x01})
    write(0x0100, 0x88)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "asl accumulator" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x02})
    write(0x0100, 0x0A)
    MOS6502.step()
    assert %{accumulator: 0x04} = get_registers()
  end

  test "asl zero page" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0x06)
    write(0x0101, 0x84)
    write(0x0084, 0x02)
    MOS6502.step()
    assert {:ok, 0x04} == read(0x0084)
  end

  test "asl zero page x" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0x01})
    write(0x0100, 0x16)
    write(0x0101, 0x84)
    write(0x0085, 0x02)
    MOS6502.step()
    assert {:ok, 0x04} == read(0x0085)
  end

  test "asl absolute" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0x0E)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0084, 0x02)
    MOS6502.step()
    assert {:ok, 0x04} = read(0x0084)
  end

  test "asl absolute x" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0x01})
    write(0x0100, 0x1E)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0085, 0x02)
    MOS6502.step()
    assert {:ok, 0x04} = read(0x0085)
  end

  test "asl c flag set" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF})
    write(0x0100, 0x0A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 1) == 0
  end

  test "asl c flag unset" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x01})
    write(0x0100, 0x0A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 1) == 0
  end

  test "asl z flag set" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x00})
    write(0x0100, 0x0A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "asl z flag unset" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x02})
    write(0x0100, 0x0A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "asl n flag set" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFE})
    write(0x0100, 0x0A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "asl n flag unset" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x01})
    write(0x0100, 0x0A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "lsr accumulator" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x02})
    write(0x0100, 0x4A)
    MOS6502.step()
    assert %{accumulator: 0x01} = get_registers()
  end

  test "lsr zero page" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0x46)
    write(0x0101, 0x84)
    write(0x0084, 0x02)
    MOS6502.step()
    assert {:ok, 0x01} == read(0x0084)
  end

  test "lsr zero page x" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0x01})
    write(0x0100, 0x56)
    write(0x0101, 0x84)
    write(0x0085, 0x02)
    MOS6502.step()
    assert {:ok, 0x01} == read(0x0085)
  end

  test "lsr absolute" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0x4E)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0084, 0x02)
    MOS6502.step()
    assert {:ok, 0x01} = read(0x0084)
  end

  test "lsr absolute x" do
    set_registers(%{get_registers() | program_counter: 0x0100, x: 0x01})
    write(0x0100, 0x5E)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0085, 0x02)
    MOS6502.step()
    assert {:ok, 0x01} = read(0x0085)
  end

  test "lsr c flag set" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFF})
    write(0x0100, 0x4A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 1) == 0
  end

  test "lsr c flag unset" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x10})
    write(0x0100, 0x4A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 1) == 0
  end

  test "lsr z flag set" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x01})
    write(0x0100, 0x4A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "lsr z flag unset" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x02})
    write(0x0100, 0x4A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "lsr n flag unset" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x01})
    write(0x0100, 0x4A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "rol accumulator" do
    %{processor_status: processor_status} = get_registers()
    processor_status = processor_status ||| 1

    set_registers(%{
      get_registers()
      | program_counter: 0x0100,
        accumulator: 0x02,
        processor_status: processor_status
    })

    write(0x0100, 0x2A)
    MOS6502.step()
    assert %{accumulator: 0x05} = get_registers()
  end

  test "rol zero page" do
    %{processor_status: processor_status} = get_registers()
    processor_status = processor_status ||| 1

    set_registers(%{get_registers() | program_counter: 0x0100, processor_status: processor_status})

    write(0x0100, 0x26)
    write(0x0101, 0x84)
    write(0x0084, 0x02)
    MOS6502.step()
    assert {:ok, 0x05} == read(0x0084)
  end

  test "rol zero page x" do
    %{processor_status: processor_status} = get_registers()
    processor_status = processor_status ||| 1

    set_registers(%{
      get_registers()
      | program_counter: 0x0100,
        processor_status: processor_status,
        x: 0x01
    })

    write(0x0100, 0x36)
    write(0x0101, 0x84)
    write(0x0085, 0x02)
    MOS6502.step()
    assert {:ok, 0x05} == read(0x0085)
  end

  test "rol absolute" do
    %{processor_status: processor_status} = get_registers()
    processor_status = processor_status ||| 1

    set_registers(%{get_registers() | program_counter: 0x0100, processor_status: processor_status})

    write(0x0100, 0x2E)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0084, 0x02)
    MOS6502.step()
    assert {:ok, 0x05} == read(0x0084)
  end

  test "rol absolute x" do
    %{processor_status: processor_status} = get_registers()
    processor_status = processor_status ||| 1

    set_registers(%{
      get_registers()
      | program_counter: 0x0100,
        processor_status: processor_status,
        x: 0x01
    })

    write(0x0100, 0x3E)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0085, 0x02)
    MOS6502.step()
    assert {:ok, 0x05} == read(0x0085)
  end

  test "rol c flag set" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x80})
    write(0x0100, 0x2A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 1) == 0
  end

  test "rol c flag unset" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x01})
    write(0x0100, 0x2A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 1) == 0
  end

  test "rol z flag set" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x00})
    write(0x0100, 0x2A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "rol z flag unset" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x02})
    write(0x0100, 0x2A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "rol n flag set" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xFE})
    write(0x0100, 0x2A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "rol n flag unset" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x01})
    write(0x0100, 0x2A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "ror accumulator" do
    %{processor_status: processor_status} = get_registers()
    processor_status = processor_status ||| 1

    set_registers(%{
      get_registers()
      | program_counter: 0x0100,
        accumulator: 0x08,
        processor_status: processor_status
    })

    write(0x0100, 0x6A)
    MOS6502.step()
    assert %{accumulator: 0x84} = get_registers()
  end

  test "ror zero page" do
    %{processor_status: processor_status} = get_registers()
    processor_status = processor_status ||| 1

    set_registers(%{get_registers() | program_counter: 0x0100, processor_status: processor_status})

    write(0x0100, 0x66)
    write(0x0101, 0x84)
    write(0x0084, 0x08)
    MOS6502.step()
    assert {:ok, 0x84} == read(0x0084)
  end

  test "ror zero page x" do
    %{processor_status: processor_status} = get_registers()
    processor_status = processor_status ||| 1

    set_registers(%{
      get_registers()
      | program_counter: 0x0100,
        processor_status: processor_status,
        x: 0x01
    })

    write(0x0100, 0x76)
    write(0x0101, 0x84)
    write(0x0085, 0x08)
    MOS6502.step()
    assert {:ok, 0x84} == read(0x0085)
  end

  test "ror absolute" do
    %{processor_status: processor_status} = get_registers()
    processor_status = processor_status ||| 1

    set_registers(%{get_registers() | program_counter: 0x0100, processor_status: processor_status})

    write(0x0100, 0x6E)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0084, 0x08)
    MOS6502.step()
    assert {:ok, 0x84} == read(0x0084)
  end

  test "ror absolute x" do
    %{processor_status: processor_status} = get_registers()
    processor_status = processor_status ||| 1

    set_registers(%{
      get_registers()
      | program_counter: 0x0100,
        processor_status: processor_status,
        x: 0x01
    })

    write(0x0100, 0x7E)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0085, 0x08)
    MOS6502.step()
    assert {:ok, 0x84} == read(0x0085)
  end

  test "ror c flag set" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x01})
    write(0x0100, 0x6A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 1) == 0
  end

  test "ror c flag unset" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x10})
    write(0x0100, 0x6A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 1) == 0
  end

  test "ror z flag set" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x00})
    write(0x0100, 0x6A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 2) == 0
  end

  test "ror z flag unset" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0x02})
    write(0x0100, 0x6A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 2) == 0
  end

  test "ror n flag set" do
    %{processor_status: processor_status} = get_registers()
    processor_status = processor_status ||| 1

    set_registers(%{
      get_registers()
      | program_counter: 0x0100,
        accumulator: 0xFE,
        processor_status: processor_status
    })

    write(0x0100, 0x6A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    refute (processor_status &&& 128) == 0
  end

  test "ror n flag unset" do
    %{processor_status: processor_status} = get_registers()
    processor_status = processor_status &&& ~~~1

    set_registers(%{
      get_registers()
      | program_counter: 0x0100,
        accumulator: 0x01,
        processor_status: processor_status
    })

    write(0x0100, 0x6A)
    MOS6502.step()
    %{processor_status: processor_status} = get_registers()
    assert (processor_status &&& 128) == 0
  end

  test "jmp" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0x4C)
    write(0x0101, 0xFF)
    write(0x0102, 0x01)
    MOS6502.step()
    assert %{program_counter: 0x01FF} = get_registers()
  end

  test "jmp indirect" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0x6C)
    write(0x0101, 0x84)
    write(0x0102, 0x01)
    write(0x0184, 0xFF)
    write(0x0185, 0xFF)
    MOS6502.step()
    assert %{program_counter: 0xFFFF} = get_registers()
  end

  test "jsr - case 1" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0x20)
    write(0x0101, 0xFF)
    write(0x0102, 0x01)
    MOS6502.step()
    assert %{program_counter: 0x01FF} = get_registers()
    assert {:ok, 0x01} = read(0x01FD)
    assert {:ok, 0x02} = read(0x01FC)
  end

  test "jsr - case 2" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0x20)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0084, 0x60)
    MOS6502.step()
    MOS6502.step()
    assert %{program_counter: 0x0103, stack_pointer: 0xFD} = get_registers()
  end

  test "jsr - case 3" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    write(0x0100, 0x20)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0103, 0xA9)
    write(0x0104, 0xFF)
    write(0x0105, 0x02)
    write(0x0084, 0x60)
    MOS6502.run()
    assert %{accumulator: 0xFF} = get_registers()
  end

  test "rts" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    MOS6502.push16(0x0102)
    write(0x0100, 0x60)
    MOS6502.step()
    assert %{program_counter: 0x0103} = get_registers()
  end

  test "bcc" do
    %{processor_status: processor_status} = get_registers()
    processor_status = processor_status ||| 1

    set_registers(%{get_registers() | program_counter: 0x0100, processor_status: processor_status})

    write(0x0100, 0x90)
    assert {:ok, 2} = MOS6502.step()
    assert %{program_counter: 0x0102, processor_status: processor_status} = get_registers()
    processor_status = processor_status &&& ~~~1

    set_registers(%{get_registers() | program_counter: 0x0100, processor_status: processor_status})

    write(0x0100, 0x90)
    write(0x0101, 0x02)
    assert {:ok, 3} = MOS6502.step()
    assert %{program_counter: 0x0104, processor_status: processor_status} = get_registers()
    processor_status = processor_status &&& ~~~1

    set_registers(%{get_registers() | program_counter: 0x0100, processor_status: processor_status})

    write(0x0100, 0x90)
    write(0x0101, 0xFD)
    assert {:ok, 4} = MOS6502.step()
    assert %{program_counter: 0x00FF} = get_registers()
  end

  for {instruction, opcode, fn_status} <- [
        {0xB0, "bcs",
         quote do
           fn processor_status -> processor_status ||| 1 end
         end},
        {0xF0, "beq",
         quote do
           fn processor_status -> processor_status ||| 2 end
         end},
        {0x70, "bvs",
         quote do
           fn processor_status -> processor_status ||| 64 end
         end},
        {0x30, "bmi",
         quote do
           fn processor_status -> processor_status ||| 128 end
         end},
        {0xD0, "bne",
         quote do
           fn processor_status -> processor_status &&& ~~~2 end
         end},
        {0x10, "bpl",
         quote do
           fn processor_status -> processor_status &&& ~~~128 end
         end},
        {0x50, "bvc",
         quote do
           fn processor_status -> processor_status &&& ~~~64 end
         end}
      ] do
    test opcode do
      %{processor_status: processor_status} = get_registers()
      processor_status = unquote(fn_status).(processor_status)

      set_registers(%{
        get_registers()
        | program_counter: 0x0100,
          processor_status: processor_status
      })

      write(0x0100, unquote(instruction))
      write(0x0101, 0x02)
      MOS6502.step()
      assert %{program_counter: 0x0104} = get_registers()
      %{processor_status: processor_status} = get_registers()
      processor_status = unquote(fn_status).(processor_status)

      set_registers(%{
        get_registers()
        | program_counter: 0x0100,
          processor_status: processor_status
      })

      write(0x0100, unquote(instruction))
      write(0x0101, 0xFE)
      MOS6502.step()
      assert %{program_counter: 0x0100} = get_registers()
    end
  end

  for {instruction, opcode, flag, fn_comp, fn_status_1, fn_status_2} <- [
        {0x18, "clc", 1,
         quote do
           &Kernel.==/2
         end,
         quote do
           fn processor_status ->
             processor_status &&& ~~~1
           end
         end,
         quote do
           fn processor_status ->
             processor_status ||| 1
           end
         end},
        {0xD8, "cld", 8,
         quote do
           &Kernel.==/2
         end,
         quote do
           fn processor_status ->
             processor_status &&& ~~~8
           end
         end,
         quote do
           fn processor_status ->
             processor_status ||| 8
           end
         end},
        {0x58, "cli", 4,
         quote do
           &Kernel.==/2
         end,
         quote do
           fn processor_status ->
             processor_status &&& ~~~4
           end
         end,
         quote do
           fn processor_status ->
             processor_status ||| 4
           end
         end},
        {0xB8, "clv", 64,
         quote do
           &Kernel.==/2
         end,
         quote do
           fn processor_status ->
             processor_status &&& ~~~64
           end
         end,
         quote do
           fn processor_status ->
             processor_status ||| 64
           end
         end},
        {0x38, "sec", 1,
         quote do
           &Kernel.!=/2
         end,
         quote do
           fn processor_status ->
             processor_status &&& ~~~1
           end
         end,
         quote do
           fn processor_status ->
             processor_status ||| 1
           end
         end},
        {0xF8, "sed", 8,
         quote do
           &Kernel.!=/2
         end,
         quote do
           fn processor_status ->
             processor_status &&& ~~~8
           end
         end,
         quote do
           fn processor_status ->
             processor_status ||| 8
           end
         end},
        {0x78, "sei", 4,
         quote do
           &Kernel.!=/2
         end,
         quote do
           fn processor_status ->
             processor_status &&& ~~~4
           end
         end,
         quote do
           fn processor_status ->
             processor_status ||| 4
           end
         end}
      ] do
    test opcode do
      %{processor_status: processor_status} = get_registers()
      processor_status = unquote(fn_status_1).(processor_status)

      set_registers(%{
        get_registers()
        | program_counter: 0x0100,
          processor_status: processor_status
      })

      write(0x0100, unquote(instruction))
      MOS6502.step()
      %{processor_status: processor_status} = get_registers()
      assert unquote(fn_comp).(processor_status &&& unquote(flag), 0)
      %{processor_status: processor_status} = get_registers()
      processor_status = unquote(fn_status_2).(processor_status)

      set_registers(%{
        get_registers()
        | program_counter: 0x0100,
          processor_status: processor_status
      })

      write(0x0100, unquote(instruction))
      MOS6502.step()
      %{processor_status: processor_status} = get_registers()
      assert unquote(fn_comp).(processor_status &&& unquote(flag), 0)
    end
  end

  test "brk" do
    set_registers(%{get_registers() | program_counter: 0x0100, processor_status: 0xFF &&& ~~~16})
    write(0x0100, 0x00)
    write(0xFFFE, 0xFF)
    write(0xFFFF, 0x01)
    MOS6502.step()
    assert {:ok, 0xFF} = MOS6502.pop()
    assert {:ok, 0x0102} = MOS6502.pop16()
    assert %{program_counter: 0x01FF} = get_registers()
  end

  test "rti" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    MOS6502.push16(0x0102)
    MOS6502.push(0x03)
    write(0x0100, 0x40)
    MOS6502.step()
    assert %{program_counter: 0x0102, processor_status: 0x03} = get_registers()
  end

  test "irq" do
    set_registers(%{get_registers() | program_counter: 0x0100, processor_status: 0xFB})
    MOS6502.irq()
    write(0xFFFE, 0x40)
    write(0xFFFF, 0x01)
    MOS6502.interrupt()
    assert {:ok, 0xEB} = MOS6502.pop()
    assert {:ok, 0x0100} = MOS6502.pop16()
    assert %{program_counter: 0x0140} = get_registers()
    assert %{irq: false} = MOS6502.get_state()
  end

  test "nmi" do
    set_registers(%{get_registers() | program_counter: 0x0100, processor_status: 0xFF})
    MOS6502.nmi()
    write(0xFFFA, 0x40)
    write(0xFFFB, 0x01)
    MOS6502.interrupt()
    assert {:ok, 0xEF} = MOS6502.pop()
    assert {:ok, 0x0100} = MOS6502.pop16()
    assert %{program_counter: 0x0140} = get_registers()
    assert %{nmi: false} = MOS6502.get_state()
  end

  test "rst" do
    set_registers(%{get_registers() | program_counter: 0x0100})
    MOS6502.rst()
    write(0xFFFC, 0x40)
    write(0xFFFD, 0x01)
    MOS6502.interrupt()
    assert %{program_counter: 0x0140} = get_registers()
    assert %{rst: false} = MOS6502.get_state()
  end

  # Helpers
  def get_registers, do: MOS6502.get_registers()

  def set_registers(registers),
    do: MOS6502.set_registers(registers)

  defp read(address), do: Memory.read(MOS6502.memory_server_name(), address)
  defp write(address, value), do: Memory.write(MOS6502.memory_server_name(), address, value)
end
