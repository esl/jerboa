defmodule Jerboa.Format do
  @moduledoc """
  Encode and decode the STUN wire format
  """

  alias Jerboa.Format.{Meta, Header,Body, MessageIntegrity}
  alias Jerboa.Format.{HeaderLengthError, BodyLengthError}
  alias Jerboa.Params

  @doc """
  Encode a complete set of parameters into a binary suitable writing
  to the network

  ## Calculating message integrity

  In order to calculate message integrity over encoded message,
  encoder must know three values: username (as in USERNAME attribute),
  realm (REALM) and secret.

  Realm value *must* be present in attributes
  list of params struct. Username can be provided in options list,
  but USERNAME attribute will override it if present. Secret *must*
  be provided in option list.

  If any of these values is missing, message integrity won't be applied
  and encoding will succeed. None of these values will be validated,
  so encoding will fail if, for example, provided username is an integer.

  ## Available options

  * `:secret` - secret used for calculating message integrity
  * `:username` - username used for calculating message integrity
    if USERNAME attribute can't be found in params struct
  """
  @spec encode(Params.t, options :: Keyword.t) :: binary
  def encode(params, options \\ []) do
    %Meta{params: params, options: options}
    |> Body.encode()
    |> Header.encode()
    |> MessageIntegrity.apply()
    |> concatenate()
  end

  @spec decode!(binary)
    :: Params.t | {Params.t, extra :: binary} | no_return
  @doc """
  The same as `decode/1` but raises one of various exceptions if the
  binary doesn't encode a STUN message
  """
  def decode!(bin) do
    case decode(bin) do
      {:ok, params} ->
        params
      {:ok, params, extra} ->
        {params, extra}
      {:error, e} ->
        raise e
    end
  end

  @doc """
  Decode a binary into a complete set of STUN message parameters

  Return an `:ok` tuple or an `:error` tuple with an error struct if
  the binary doesn't encode a STUN message. Returns `{:ok, params, extra}`
  if given binary was longer than declared in STUN header.
  """
  @spec decode(binary)
    :: {:ok, Params.t} | {:ok, Params.t, extra :: binary} | {:error, struct}
  def decode(bin) when is_binary(bin) and byte_size(bin) < 20 do
    {:error, HeaderLengthError.exception(binary: bin)}
  end
  def decode(<<header::20-binary, body::binary>>) do
    meta = %Meta{header: header, body: body}
    with {:ok, meta} <- decode_header(meta),
         {:ok, meta} <- Body.decode(meta) do
      maybe_with_extra(meta)
    end
  end

  defp concatenate(%Meta{header: header, body: body}) do
    header <> body
  end

  @spec decode_header(Meta.t) :: {:ok, Meta.t} | {:error, struct}
  defp decode_header(meta) do
    case Header.decode(meta) do
      {:ok, %Meta{body: body, length: length}} when byte_size(body) < length ->
        {:error, BodyLengthError.exception(length: byte_size(body))}
      {:ok, %Meta{body: body, length: length} = meta} when byte_size(body) > length ->
        <<trimmed_body::size(length)-bytes, extra::binary>> = body
        {:ok, %{meta | extra: extra, body: trimmed_body}}
      {:ok, _} = result ->
        result
      {:error, _} = e ->
        e
    end
  end

  defp maybe_with_extra(%Meta{extra: <<>>} = meta), do: {:ok, meta.params}
  defp maybe_with_extra(%Meta{extra: extra} = meta) do
    {:ok, meta.params, extra}
  end
end
