use EnumType

defenum Nintenlixir.CPU.ProcessorStatus do
  value(CarryFlag, 1)
  value(ZeroFlag, 2)
  value(InterruptDisable, 4)
  value(DecimalMode, 8)
  value(BreakCommand, 16)
  value(Unused, 32)
  value(OverflowFlag, 64)
  value(NegativeFlag, 128)
end
