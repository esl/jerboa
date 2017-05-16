defmodule Jerboa.Format do
  @moduledoc """
  Encode and decode the STUN wire format
  """

  alias Jerboa.Format.{Meta, Header, Body, MessageIntegrity}
  alias Jerboa.Format.{HeaderLengthError, BodyLengthError,
                       First2BitsError, ChannelDataLengthError}
  alias Jerboa.Params
  alias Jerboa.ChannelData

  @typedoc """
  Represents valid number of TURN channel
  """
  @type channel_number :: 0x4000..0x7FFF

  @min_channel_number 0x4000
  @max_channel_number 0x7FFF

  @doc """
  Encode a complete set of STUN Params or ChannelData into a binary suitable
  for writing to the network

  ## Calculating message integrity

  > This section applies only to encoding `Jerboa.Params` struct.

  In order to calculate message integrity over encoded message,
  encoder must know three values: username (as in USERNAME attribute),
  realm (REALM) and secret.

  Realm and username may be provided as attributes in params struct,
  or passed in options list. However attribute values will always override
  those found in options. Secret *must* be provided in option list.

  If any of these values are missing, message integrity won't be applied
  and encoding will succeed. None of these values (username, realm or secret)
  will be validated, so encoding will fail if, for example, provided username
  is an integer.

  Note that passing these values in options list *won't add them to
  message attributes list.

  ## Available options

  > This section applies only to encoding `Jerboa.Params` struct.

  * `:secret` - secret used for calculating message integrity
  * `:username` - username used for calculating message integrity
    if USERNAME attribute can't be found in the params struct
  * `:realm` - realm used for calculating message integrity
    if REALM attribute can't be found in params struct
  """
  @spec encode(Params.t | ChannelData.t, options :: Keyword.t) :: binary
  def encode(params_or_channel_data, options \\ [])
  def encode(%Params{} = params, options) do
    %Meta{params: params, options: options}
    |> Body.encode()
    |> Header.encode()
    |> MessageIntegrity.apply()
    |> concatenate()
  end
  def encode(%ChannelData{channel_number: number, data: data}, _)
    when number in @min_channel_number..@max_channel_number and is_binary(data) do
    length = byte_size(data)
    <<number::16, length::16, data::binary>>
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
  Decode a binary into a `Jerboa.Params` or `Jerboa.ChannelData` struct

  Return an `:ok` tuple or an `:error` tuple with an error struct if
  the binary doesn't encode a ChannelData message, a STUN message,
  or included message integrity is not valid (see "Verifying message
  integrity"). Returns `{:ok, params, extra}` if given binary was longer than
  declared in STUN or ChannelData header.

  ## Verifying message integrity

  > This section applies only to STUN messages.

  Similarly to `encode/2` decoder first looks for username and realm
  in the decoded message attributes or in the options list if there are
  no such attributes.

  Verification stage of decoding will never cause a decoding failure.
  To indicate what happened during verification, there are two fields
  in `Jerboa.Params` struct: `:signed?` and `:verified?`.

  `:signed?` is set to true **only** if the message being decoded has
  a MESSAGE-INTEGRITY attribute included. `:verified?` can never
  be true if `:signed?` is false (because there is simply nothing to
  verify).

  `:verified?` is only set to true when:
  * the message is `:signed?`
  * username, realm in the message attributes, or were passed as options
    and secret was passed as option
  * MESSAGE-INTEGRITY was successfully verified using algorithm described in RFC

  Otherwise, it's set to false.

  ## Available options

  Same as in `encode/2`.
  """
  @spec decode(binary, options :: Keyword.t)
  :: {:ok, Params.t | ChannelData.t}
   | {:ok, Params.t | ChannelData.t, extra :: binary}
   | {:error, struct}
  def decode(binary, options \\ [])
    when is_binary(binary) do
    cond do
      stun_binary?(binary) ->
        decode_stun(binary, options)
      channel_data_binary?(binary) ->
        decode_channel_data(binary)
      bit_size(binary) >= 2 ->
        <<first_two::2-bits, _::bitstring>> = binary
        {:error, First2BitsError.exception(bits: first_two)}
      true ->
        {:error, First2BitsError.exception(bits: <<>>)}
     end
   end

  @spec stun_binary?(binary) :: boolean
  defp stun_binary?(<<0::2-unit(1), _::bits>>), do: true
  defp stun_binary?(_), do: false

  @spec channel_data_binary?(binary) :: boolean
  defp channel_data_binary?(<<1::2-unit(1), _::bits>>), do: true
  defp channel_data_binary?(_), do: false

  @spec decode_stun(binary, options :: Keyword.t)
    :: {:ok, Params.t} | {:ok, Params.t, extra :: binary} | {:error, struct}
  defp decode_stun(bin, _) when is_binary(bin) and byte_size(bin) < 20 do
    {:error, HeaderLengthError.exception(binary: bin)}
  end
  defp decode_stun(<<header::20-binary, body::binary>>, options) do
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

  @spec decode_channel_data(<<_::32, _::_ * 8>>)
  :: {:ok, ChannelData.t}
   | {:ok, ChannelData.t, extra :: binary}
   | {:error, struct}
  defp decode_channel_data(<<number::16, length::16, data::size(length)-bytes,
    rest::binary>>) when number in @min_channel_number..@max_channel_number do
    channel_data = %ChannelData{channel_number: number, data: data}
    case rest do
      <<>>  -> {:ok, channel_data}
      extra -> {:ok, channel_data, extra}
    end
  end
  defp decode_channel_data(<<_::16, length::16, rest::binary>>)
    when byte_size(rest) < length do
    {:error, ChannelDataLengthError.exception(length: byte_size(rest))}
  end
end
