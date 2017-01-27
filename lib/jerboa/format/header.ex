defmodule Jerboa.Format.Header do
  @moduledoc false

  alias Jerboa.Params
  alias Jerboa.Format.Header.{Type,Length,MagicCookie,Identifier}

  @magic_cookie MagicCookie.encode

  def encode(params) do
    t = Type.encode(params)
    l = Length.encode(params)
    i = Identifier.encode(params)
    %{params | header: encode(t, l, i)}
  end

  def decode(x = %Params{header: <<0::2, t::14-bits, l::16-bits, @magic_cookie::bytes, i::96-bits>>}) do
    with {:ok, class, method} <- Type.decode(t),
         {:ok, length}        <- Length.decode(l) do
      {:ok, %{x | class: class, method: method, length: length, identifier: i}}
    else
      {:error, _} = e ->
        e
    end
  end
  def decode(%Params{header: <<0::2, _::30, _::128>> = header}) do
    {:error, Jerboa.Format.MagicCookieError.exception(header: header)}
  end
  def decode(%Params{header: <<b::2, _::158>>}) do
    {:error, Jerboa.Format.First2BitsError.exception(bits: b)}
  end

  defp encode(type, length, identifier) do
    <<0::2, type::bits, length::bytes, @magic_cookie::bytes, identifier::bytes>>
  end
end
