defmodule Jerboa.Format.Body do
  @moduledoc false

  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Params

  def encode(params = %Params{attributes: a}) do
    %{params | body: encode(params, a)}
  end

  def decode(params = %Params{length: 0, body: <<>>}), do: {:ok, params}
  def decode(params = %Params{body: body}) do
    case decode(params, body, []) do
      {:ok, attributes} ->
        {:ok, %{params | attributes: attributes}}
      {:error, _} = e ->
        e
    end
  end

  defp encode(_, []) do
    <<>>
  end
  defp encode(params, [attr|rest]) do
    encoded = Attribute.encode(params, attr)
    encoded <> padding(encoded) <> encode(params, rest)
  end

  defp decode(params, <<t::16, l::16, v::bytes-size(l), r::binary>>, attrs) do
    rest = strip(r, padding_length(l))
    case Attribute.decode(params, t, v) do
      :ignore ->
        decode params, rest, attrs
      {:ok, attr} ->
        decode params, rest, attrs ++ [attr]
      {:error, _} = e ->
        e
    end
  end
  defp decode(_, <<>>, attrs) do
    {:ok, attrs}
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
