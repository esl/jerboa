defmodule Jerboa.Format do
  @moduledoc """
  Encode and decode the STUN wire format
  """

  alias Jerboa.Format.{Meta, Header, Body, MessageIntegrity}
  alias Jerboa.Format.{HeaderLengthError, BodyLengthError}
  alias Jerboa.Params

  @doc """
  Encode a complete set of parameters into a binary suitable writing
  to the network

  ## Calculating message integrity

  In order to calculate message integrity over encoded message,
  encoder must know three values: username (as in USERNAME attribute),
  realm (REALM) and secret.

  Realm and username may be provided as attributes in params struct,
  or passed in options list. However attribute values will always override
  those found in options. Secret *must* be provided in option list.

  If any of these values is missing, message integrity won't be applied
  and encoding will succeed. None of these values will be validated,
  so encoding will fail if, for example, provided username is an integer.

  Note that passing these values in options list *won't add them to
  message attributes list*.

  ## Available options

  * `:secret` - secret used for calculating message integrity
  * `:username` - username used for calculating message integrity
    if USERNAME attribute can't be found in params struct
  * `:realm` - realm used for calculating message integrity
    if REALM attribute can't be found in params struct
  """
  @spec encode(Params.t, options :: Keyword.t) :: binary
  def encode(params, options \\ []) do
    %Meta{params: params, options: options}
    |> Body.encode()
    |> Header.encode()
    |> MessageIntegrity.apply()
    |> concatenate()
  end

  @doc """
  The same as `decode/1` but raises one of various exceptions if the
  binary doesn't encode a STUN message
  """
  @spec decode!(binary, options :: Keyword.t)
    :: Params.t | {Params.t, extra :: binary} | no_return
  def decode!(bin, options \\ []) do
    case decode(bin, options) do
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
  the binary doesn't encode a STUN message, or included message integrity
  is not valid (see "Verifying message integrity"). Returns
  `{:ok, params, extra}` if given binary was longer than declared in
  STUN header.

  ## Verifying message integrity

  Similarly to `encode/2` decoder first looks for username and realm
  in decoded message attributes or in the options list if there are
  no such attributes.

  However, note that we can't be sure what comes from the other end of the wire,
  so we don't know if those attributes will be there (STUN/TURN RFCs define such
  behaviour, e.g. TURN server never includes USERNAME attribute in responses).

  Decoding will fail if necessary values (username, realm and secret) can't
  be found, so it's better to always pass these values as options just to be
  sure.

  ## Available options

  Same as in `encode/2`.
  """
  @spec decode(binary, options :: Keyword.t)
    :: {:ok, Params.t} | {:ok, Params.t, extra :: binary} | {:error, struct}
  def decode(binary, options \\ [])
  def decode(bin, _) when is_binary(bin) and byte_size(bin) < 20 do
    {:error, HeaderLengthError.exception(binary: bin)}
  end
  def decode(<<header::20-binary, body::binary>>, options) do
    meta = %Meta{header: header, body: body, options: options}
    with {:ok, meta} <- decode_header(meta),
         {:ok, meta} <- Body.decode(meta),
         {:ok, meta} <- MessageIntegrity.verify(meta) do
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
