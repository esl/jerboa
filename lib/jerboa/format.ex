defmodule Jerboa.Format do
  @moduledoc """
  Encode and decode the STUN wire format
  """

  alias Jerboa.Format.{Header,Body}
  alias Jerboa.Format.{HeaderLengthError, BodyLengthError}
  alias Jerboa.Params

  @spec encode(Params.t) :: binary
  @doc """
  Encode a complete set of parameters into a binary suitable writing
  to the network
  """
  def encode(params) do
    params
    |> Body.encode
    |> Header.encode
    |> concatenate
  end

  @spec decode!(binary) :: Params.t | no_return
  @doc """
  The same as `decode/1` but raises one of various exceptions if the
  binary doesn't encode a STUN message
  """
  def decode!(bin) do
    case decode(bin) do
      {:ok, params} ->
        params
      {:error, e} ->
        raise e
    end
  end

  @spec decode(binary) :: {:ok, Params.t} | {:error, struct}
  @doc """
  Decode a binary into a complete set of STUN message parameters

  Return an `:ok` tuple or an `:error` tuple with an error struct if
  the binary doesn't encode a STUN message.
  """
  def decode(bin) when is_binary(bin) and byte_size(bin) < 20 do
    {:error, HeaderLengthError.exception(binary: bin)}
  end
  def decode(<<header::20-binary, body::binary>>) do
    case Header.decode(%Params{header: header, body: body}) do
      {:ok, %Params{body: body, length: length}} when byte_size(body) < length ->
        {:error, BodyLengthError.exception(length: byte_size(body))}
      {:ok, p = %Params{body: body, length: length}} when byte_size(body) > length ->
        <<trimmed_body::size(length)-bytes, extra::binary>> = body
        Body.decode(%{p | extra: extra, body: trimmed_body})
      {:ok, x} ->
        Body.decode(x)
      {:error, _} = e ->
        e
    end
  end

  defp concatenate(%Params{header: x, body: y}) do
    x <> y
  end
end
