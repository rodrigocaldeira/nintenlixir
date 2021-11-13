defmodule Nintenlixir.CPU.InstructionTest do
  use ExUnit.Case, async: true
  use Bitwise

  alias Nintenlixir.CPU.MOS6502
  alias Nintenlixir.Memory

  setup do
    start_supervised(MOS6502)
    start_supervised({Memory, MOS6502.memory_server_name()})
    :ok = MOS6502.reset()
    :ok = MOS6502.set_state(%{MOS6502.get_state | break_error: true})
    :ok
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
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xff})
    write(0x0100, 0x2d)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0084, 0x0f)
    MOS6502.step()
    assert %{accumulator: 0x0f} = get_registers()
  end

  test "and absolute x" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xff, x: 0x01})
    write(0x0100, 0x3d)
    write(0x0101, 0x84)
    write(0x0102, 0x00)
    write(0x0085, 0x0f)
    MOS6502.step()
    assert %{accumulator: 0x0f} = get_registers()
  end

  test "and indirect x" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xff, x: 0x01})
    write(0x0100, 0x21)
    write(0x0101, 0x84)
    write(0x0085, 0x87)
    write(0x0086, 0x00)
    write(0x0087, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0x0f} = get_registers()
  end

  test "and indirect y" do
    set_registers(%{get_registers() | program_counter: 0x0100, accumulator: 0xff, y: 0x01})
    write(0x0100, 0x31)
    write(0x0101, 0x84)
    write(0x0084, 0x86)
    write(0x0085, 0x00)
    write(0x0087, 0x0F)
    MOS6502.step()
    assert %{accumulator: 0x0f} = get_registers()
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

  # Helpers
  def get_registers, do: MOS6502.get_registers()

  def set_registers(registers),
    do: MOS6502.set_registers(registers)

    defp read(address), do: Memory.read(MOS6502.memory_server_name(), address)  
  defp write(address, value), do: Memory.write(MOS6502.memory_server_name(), address, value)
end
