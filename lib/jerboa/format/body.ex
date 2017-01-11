defmodule Jerboa.Format.Body do
  @moduledoc """

  Encode and decode attributes. Collectively we call these the
  body. We decode attributes immediately, i.e. we don't build a
  intermediate list of the name and values parts, as we want to fail
  quickly.

  """

  alias Jerboa.Format.Body.Attribute

  def decode(x = %Jerboa.Format{length: 0}), do: x
  def decode(x = %Jerboa.Format{body: b}) when is_binary(b), do: %{ x | attributes: decode(b, []) }

  defp decode(<<t :: 16, s :: integer-size(16)-unit(1), v :: bytes-size(s), r :: binary>>, attrs) do
    decode r, attrs ++ [Attribute.decode(t, v)]
  end
  defp decode(<<>>, attrs) do
    attrs
  end
end
