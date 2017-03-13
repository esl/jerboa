defmodule Jerboa.Format do
  @moduledoc """
  Encode and decode the STUN wire format
  """

  alias Jerboa.Format.{Meta, Header,Body}
  alias Jerboa.Format.{HeaderLengthError, BodyLengthError}
  alias Jerboa.Params

  @spec encode(Params.t) :: binary
  @doc """
  Encode a complete set of parameters into a binary suitable writing
  to the network
  """
  def encode(params) do
    %Meta{params: params}
    |> Body.encode()
    |> Header.encode()
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
