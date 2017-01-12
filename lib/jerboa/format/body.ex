defmodule Jerboa.Format.Body do
  @moduledoc """

  Encode and decode attributes. Collectively we call these the
  body. We decode attributes immediately, i.e. we don't build a
  intermediate list of the name and values pairs, as we want to fail
  quickly.

  """

  alias Jerboa.Format.Body.Attribute

  def decode(message = %Jerboa.Format{length: 0}), do: {:ok, message}
  def decode(message = %Jerboa.Format{body: body}) when is_binary(body) do
    case decode(body, []) do
      {:ok, attributes} ->
        {:ok, %{message | attributes: attributes}}
      {:error, _} = e ->
        e
    end
  end

  defp decode(<<t :: 16, s :: 16, v :: bytes-size(s), r :: binary>>, attrs) do
    case Attribute.decode(t, v) do
      {:ok, attr} ->
        decode r, attrs ++ [attr]
      {:error, _} = e ->
        e
    end
  end
  defp decode(<<>>, attrs) do
    {:ok, attrs}
  end
end
