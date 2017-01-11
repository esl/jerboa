defmodule Jerboa.Format.Head.Length do
  @moduledoc """

  Encode and decode body length for the STUN wire format.

  """

  def encode(%Jerboa.Format{body: b}) when is_binary(b) do
    << byte_size(b)::integer-unit(8)-size(2) >>
  end

  def decode(x = <<_::14, 0::2>>) do
    :binary.decode_unsigned x
  end
end
