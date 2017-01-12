defmodule Jerboa.Format.Body do
  @moduledoc """

  Encode and decode attributes. Collectively we call these the
  body. We decode attributes immediately, i.e. we don't build a
  intermediate list of the name and values pairs, as we want to fail
  quickly.

  """

  alias Jerboa.Format.Body.Attribute

  def decode(params = %Jerboa.Format{length: 0}), do: {:ok, params}
  def decode(params = %Jerboa.Format{body: body}) when is_binary(body) do
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
