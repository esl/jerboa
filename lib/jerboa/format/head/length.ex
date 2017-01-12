defmodule Jerboa.Format.Head.Length do
  @moduledoc """

  Encode and decode body length for the STUN wire format.

  """

  defmodule Last2BitsError do
    defexception [:message, :bits]

    def message(%__MODULE__{}) do
      "all STUN attributes are padded to a multiple of 4 bytes so the last 2 bits of this field should be zero"
    end
  end

  def encode(%Jerboa.Format{body: b}) when is_binary(b) do
    << byte_size(b)::integer-unit(8)-size(2) >>
  end

  def decode(x = <<_::14, 0::2>>) do
    {:ok, :binary.decode_unsigned x}
  end
  def decode(<<_::14, b::2>>) do
    {:error, Last2BitsError.exception(bits: b)}
  end
end
