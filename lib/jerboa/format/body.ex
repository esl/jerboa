defmodule Jerboa.Format.Body do
  @moduledoc false

  alias Jerboa.Format.Body.Attribute

  defmodule LengthError do
    defexception [:message, :length]

    def message(%__MODULE__{}) do
      "message body is shorter than specified length"
    end
  end

  def decode(params = %Jerboa.Format{length: 0, body: <<>>}), do: {:ok, params}
  def decode(params = %Jerboa.Format{body: body}) do
    case decode(params, body, []) do
      {:ok, attributes} ->
        {:ok, %{params | attributes: attributes}}
      {:error, _} = e ->
        e
    end
  end

  defp decode(params, <<t::16, s::16, c::bytes-size(s), r::binary>>, attrs) do
    v =  strip(c, padding(s))
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

  defp strip(b, s) do
    <<_::bytes-size(s), b::bytes>> = b
    b
  end

  defp padding(length) do
    case rem(length, 4) do
      0 -> 0
      n -> 4 - n
    end
  end
end
