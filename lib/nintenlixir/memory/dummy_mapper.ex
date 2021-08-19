defmodule Nintenlixir.Memory.DummyMapper do
  defstruct name: "DummyMapper"

  alias Nintenlixir.Memory.Mapper
  alias __MODULE__

  def read(_address), do: "DUMMY MAPPER"

  def write(_address, data, memory) do
    List.replace_at(memory, data, 0xCAFE)
  end

  defimpl Mapper, for: DummyMapper do
    def read(_, data, _memory) do
      DummyMapper.read(data)
    end

    def write(_, address, data, memory) do
      DummyMapper.write(address, data, memory)
    end
  end
end
