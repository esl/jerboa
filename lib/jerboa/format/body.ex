defmodule Jerboa.Format.Body do
  @moduledoc """

  Encode and decode attributes. Collectively we call these the
  body. We decode attributes immediately, i.e. we don't build a
  intermediate list of the name and values pairs, as we want to fail
  quickly.

  """

  alias Jerboa.Format.Body.Attribute

  defmodule TooShortError do
    defexception [:message, :length]

    def message(%__MODULE__{}) do
      "message body is shorter than specified length"
    end
  end

  def decode(params = %Jerboa.Format{length: 0, body: <<>>}), do: {:ok, params}
  def decode(%Jerboa.Format{body: body, length: length}) when byte_size(body) < length do
      {:error, TooShortError.exception(length: byte_size(body))}
  end
  def decode(params = %Jerboa.Format{body: body, length: length}) when byte_size(body) > length do
      <<trimmed_body::size(length)-bytes, excess::binary>> = body
      decode(%{params | excess: excess, body: trimmed_body})
  end
  def decode(params = %Jerboa.Format{body: body}) do
    case decode(params, body, []) do
      {:ok, attributes} ->
        {:ok, %{params | attributes: attributes}}
      {:error, _} = e ->
        e
    end
  end

  defp decode(params, <<t::16, s::16, v::bytes-size(s), r::binary>>, attrs) do
    case Attribute.decode(params, t, v) do
      {:ok, attr} ->
        decode params, r, attrs ++ [attr]
      {:error, _} = e ->
        e
    end
  end
  defp decode(_, <<>>, attrs) do
    {:ok, attrs}
  end
end
