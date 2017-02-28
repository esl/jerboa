defmodule Jerboa.Test.Helper.Attribute do
  @moduledoc false

  def total(x) do
    x |> Keyword.values |> Enum.sum
  end

  def length_correct?(<<_::16, byte_length::16, _::size(byte_length)-bytes>>, byte_length) do
    true
  end
  def length_correct?(_, _), do: false

  def type(<<type::16, _::binary>>), do: type
end
