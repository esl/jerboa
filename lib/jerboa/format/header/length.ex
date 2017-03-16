defmodule Jerboa.Format.Header.Length do
  @moduledoc false

  alias Jerboa.Format.Last2BitsError
  alias Jerboa.Format.Meta

  @spec encode(Meta.t) :: length :: binary
  def encode(%Meta{body: b}) when is_binary(b) do
    <<byte_size(b)::16>>
  end

  def decode(<<_::14, 0::2>> = x) do
    {:ok, :binary.decode_unsigned x}
  end
  def decode(bin_length) do
    <<length::16>> = bin_length
    {:error, Last2BitsError.exception(length: length)}
  end
end
