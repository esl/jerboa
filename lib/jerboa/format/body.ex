defmodule Jerboa.Format.Body do
  @moduledoc false

  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Format.AttributeFormatError
  alias Jerboa.Format.Meta
  alias Jerboa.Format.MessageIntegrity

  @message_integrity MessageIntegrity.type_code

  @spec encode(Meta.t) :: Meta.t
  def encode(%Meta{params: params} = meta) do
    Enum.reduce params.attributes, meta, &encode/2
  end

  @spec decode(Meta.t) :: {:ok, Meta.t} | {:error, struct}
  def decode(%Meta{length: 0, body: <<>>} = meta), do: {:ok, meta}
  def decode(%Meta{body: body} = meta) do
    case decode(meta, body) do
      {:ok, meta} ->
        {:ok, meta}
      {:error, _} = e ->
        e
    end
  end

  @spec encode(Attribute.t, Meta.t) :: Meta.t
  defp encode(attr, meta) do
    {meta, encoded} = Attribute.encode(meta, attr)
    %{meta | body: meta.body <> encoded <> padding(encoded)}
  end

  @spec decode(Meta.t, not_decoded :: binary) :: {:ok, Meta.t} | {:error, struct}
  defp decode(meta, <<@message_integrity::16, l::16, _v::size(l)-bytes,
    _::binary>> = body) do
    MessageIntegrity.extract(meta, body)
  end
  defp decode(meta, <<t::16, l::16, v::bytes-size(l), r::binary>>) do
    padding_length = padding_length(l)
    rest = strip(r, padding_length)
    new_length_up_to_integrity =
      meta.length_up_to_integrity + 4 + l + padding_length
    meta = %{meta | length_up_to_integrity: new_length_up_to_integrity}
    case Attribute.decode(meta, t, v) do
      {:ignore, meta} ->
        decode meta, rest
      {:ok, meta, attr} ->
        params = meta.params
        new_params = %{params | attributes: [attr|params.attributes]}
        decode %{meta | params: new_params}, rest
      {:error, _} = e ->
        e
    end
  end
  defp decode(meta, <<>>) do
    {:ok, meta}
  end
  defp decode(_, _) do
    {:error, AttributeFormatError.exception()}
  end

  defp strip(binary, padding_len) do
    <<_::bytes-size(padding_len), rest::binary>> = binary
    rest
  end

  defp padding_length(length) do
    case rem(length, 4) do
      0 -> 0
      n -> 4 - n
    end
  end

  defp padding(attr) do
    padding_length = padding_length(byte_size(attr))
    String.duplicate(<<0>>, padding_length)
  end
end
