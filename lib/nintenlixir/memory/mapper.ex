defprotocol Nintenlixir.Memory.Mapper do
  def read(mapper, address, memory)
  def write(mapper, address, data, memory)
end
