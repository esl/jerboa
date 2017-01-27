defmodule Jerboa.Format.Header.Length do
  @moduledoc false

  alias Jerboa.Format.Last2BitsError
  alias Jerboa.Params

  def encode(%Params{body: b}) when is_binary(b) do
    <<byte_size(b)::integer-unit(8)-size(2)>>
  end

  def decode(x = <<_::14, 0::2>>) do
    {:ok, :binary.decode_unsigned x}
  end
  def decode(bin_length) do
    <<length::16>> = bin_length
    {:error, Last2BitsError.exception(length: length)}
  end
end
