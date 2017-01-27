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
    Attribute.encode(params, attr) <> encode(params, rest)
  end

  defp decode(params, <<t::16, s::16, c::bytes-size(s), r::binary>>, attrs) do
    v =  strip(c, padding(s))
    case Attribute.decode(params, t, v) do
      :ignore ->
        decode params, r, attrs
      {:ok, attr} ->
        decode params, r, attrs ++ [attr]
      {:error, _} = e ->
        e
    end
  end
  defp decode(_, <<>>, attrs) do
    {:ok, attrs}
  end

  defp strip(binary, padding) do
    size = byte_size(binary) - padding
    <<b::bytes-size(size), _::binary>> = binary
    b
  end

  defp padding(length) do
    case rem(length, 4) do
      0 -> 0
      n -> 4 - n
    end
  end
end
