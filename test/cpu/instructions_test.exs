defmodule Nintenlixir.CPU.InstructionTest do
  use ExUnit.Case, async: true

  alias Nintenlixir.CPU.MOS6502
  alias Nintenlixir.CPU.Instructions
  alias Nintenlixir.Memory
  alias Nintenlixir.CPU.Registers

  setup do
    start_supervised(MOS6502)
    start_supervised(Memory)
    start_supervised({Registers, MOS6502.registers_server_name()})
    :ok
  end

  test "Invalid opcode" do
    assert {:error, :invalid_opcode} = Instructions.execute(0xFFFF)
  end

  test "LDA" do
    assert {:ok, _} = Instructions.execute(0xA1)
  end

  test "LDX" do
    assert {:ok, _} = Instructions.execute(0xA2)
  end

  test "LDY" do
    assert {:ok, _} = Instructions.execute(0xA0)
  end

  test "STA" do
    assert {:ok, _} = Instructions.execute(0x81)
  end

  test "STX" do
    assert {:ok, _} = Instructions.execute(0x86)
  end

  test "STY" do
    assert {:ok, _} = Instructions.execute(0x84)
  end

  test "TAX" do
    assert {:ok, _} = Instructions.execute(0xAA)
  end

  test "TAY" do
    assert {:ok, _} = Instructions.execute(0xA8)
  end

  test "TXA" do
    assert {:ok, _} = Instructions.execute(0x8A)
  end

  test "TYA" do
    assert {:ok, _} = Instructions.execute(0x98)
  end

  test "TSX" do
    assert {:ok, _} = Instructions.execute(0xBA)
  end

  test "PHA" do
    assert {:ok, _} = Instructions.execute(0x48)
  end

  test "PHP" do
    assert {:ok, _} = Instructions.execute(0x08)
  end

  test "PLA" do
    assert {:ok, _} = Instructions.execute(0x68)
  end

  test "PLP" do
    assert {:ok, _} = Instructions.execute(0x28)
  end

  test "AND" do
    assert {:ok, _} = Instructions.execute(0x21)
  end

  test "XOR" do
    assert {:ok, _} = Instructions.execute(0x41)
  end

  test "ORA" do
    assert {:ok, _} = Instructions.execute(0x01)
  end

  test "BIT" do
    assert {:ok, _} = Instructions.execute(0x24)
  end

  test "ADC" do
    assert {:ok, _} = Instructions.execute(0x61)
  end

  test "SBC" do
    assert {:ok, _} = Instructions.execute(0xE1)
  end

  test "DCP" do
    assert {:ok, _} = Instructions.execute(0xC3)
  end

  test "ISB" do
    assert {:ok, _} = Instructions.execute(0xE3)
  end

  test "SLO" do
    assert {:ok, _} = Instructions.execute(0x03)
  end

  test "RLA" do
    assert {:ok, _} = Instructions.execute(0x23)
  end

  test "SRE" do
    assert {:ok, _} = Instructions.execute(0x43)
  end

  test "RRA" do
    assert {:ok, _} = Instructions.execute(0x63)
  end

  test "CMP" do
    assert {:ok, _} = Instructions.execute(0xC1)
  end

  test "CPX" do
    assert {:ok, _} = Instructions.execute(0xE0)
  end

  test "CPY" do
    assert {:ok, _} = Instructions.execute(0xC0)
  end

  test "INC" do
    registers = get_registers()
    assert {:ok, _} = Instructions.execute(0xE6)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0xF6)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0xEE)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0xFE)
  end

  test "INX" do
    assert {:ok, _} = Instructions.execute(0xE8)
  end

  test "INY" do
    assert {:ok, _} = Instructions.execute(0xC8)
  end

  test "DEC" do
    registers = get_registers()
    assert {:ok, _} = Instructions.execute(0xC6)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0xD6)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0xCE)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0xDE)
  end

  test "DEX" do
    assert {:ok, _} = Instructions.execute(0xCA)
  end

  test "DEY" do
    assert {:ok, _} = Instructions.execute(0x88)
  end

  test "ASL" do
    registers = get_registers()
    assert {:ok, _} = Instructions.execute(0x0A)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0x06)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0x16)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0x0E)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0x1E)
  end

  test "LSR" do
    registers = get_registers()
    assert {:ok, _} = Instructions.execute(0x4A)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0x46)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0x56)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0x4E)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0x5E)
  end

  test "ROL" do
    registers = get_registers()
    assert {:ok, _} = Instructions.execute(0x2A)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0x26)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0x36)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0x2E)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0x3E)
  end

  test "ROR" do
    registers = get_registers()
    assert {:ok, _} = Instructions.execute(0x6A)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0x66)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0x76)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0x6E)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0x7E)
  end

  test "JMP" do
    registers = get_registers()
    assert {:ok, _} = Instructions.execute(0x4C)

    set_registers(registers)
    assert {:ok, _} = Instructions.execute(0x6C)
  end

  test "JSR" do
    assert {:ok, _} = Instructions.execute(0x20)
  end

  test "RTS" do
    assert {:ok, _} = Instructions.execute(0x60)
  end

  test "BCC" do
    assert {:ok, _} = Instructions.execute(0x90)
  end

  test "BCS" do
    assert {:ok, _} = Instructions.execute(0xB0)
  end

  test "BEQ" do
    assert {:ok, _} = Instructions.execute(0xF0)
  end

  test "BMI" do
    assert {:ok, _} = Instructions.execute(0x30)
  end

  test "BNE" do
    assert {:ok, _} = Instructions.execute(0xD0)
  end

  test "BPL" do
    assert {:ok, _} = Instructions.execute(0x10)
  end

  test "BVC" do
    assert {:ok, _} = Instructions.execute(0x50)
  end

  test "BVS" do
    assert {:ok, _} = Instructions.execute(0x70)
  end

  test "CLC" do
    assert {:ok, _} = Instructions.execute(0x18)
  end

  test "CLD" do
    assert {:ok, _} = Instructions.execute(0xD8)
  end

  test "CLI" do
    assert {:ok, _} = Instructions.execute(0x58)
  end

  test "CLV" do
    assert {:ok, _} = Instructions.execute(0xB8)
  end

  test "SEC" do
    assert {:ok, _} = Instructions.execute(0x38)
  end

  test "SED" do
    assert {:ok, _} = Instructions.execute(0xF8)
  end

  test "SEI" do
    assert {:ok, _} = Instructions.execute(0x78)
  end

  test "BRK" do
    assert {:ok, _} = Instructions.execute(0x00)
  end

  test "NOOP" do
    for noop_opcode <- [0xEA, 0x1A, 0x3A, 0x5A, 0x7A, 0xDA, 0xFA] do
      assert {:ok, _} = Instructions.execute(noop_opcode)
    end

    assert {:ok, _} = Instructions.execute(0x80)

    assert {:ok, _} = Instructions.execute(0x0C)
  end

  test "LAX" do
    assert {:ok, _} = Instructions.execute(0xA3)
  end

  test "SAX" do
    assert {:ok, _} = Instructions.execute(0x83)
  end

  test "ANC" do
    assert {:ok, _} = Instructions.execute(0x0B)
  end

  test "ALR" do
    assert {:ok, _} = Instructions.execute(0x4B)
  end

  test "ARR" do
    assert {:ok, _} = Instructions.execute(0x6B)
  end

  test "AXS" do
    assert {:ok, _} = Instructions.execute(0xCB)
  end

  test "SHY" do
    assert {:ok, _} = Instructions.execute(0x9C)
  end

  test "SHX" do
    assert {:ok, _} = Instructions.execute(0x9E)
  end

  test "RTI" do
    assert {:ok, _} = Instructions.execute(0x40)
  end

  # Helpers
  def get_registers, do: Registers.get_registers(MOS6502.registers_server_name())

  def set_registers(registers),
    do: Registers.set_registers(MOS6502.registers_server_name(), registers)
end
