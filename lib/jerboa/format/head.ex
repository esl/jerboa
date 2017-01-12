defmodule Jerboa.Format.Head do
  @moduledoc """

  Encode and decode headers for the STUN wire format.

  """

  alias Jerboa.Format.Head.{Type,Length,MagicCookie,Identifier}

  @magic_cookie MagicCookie.encode

  def encode(params) do
    t = Type.encode(params)
    l = Length.encode(params)
    i = Identifier.encode(params)
    encode t, l, i
  end

  def decode(x = %Jerboa.Format{head: <<0::2, t::14-bits, l::16-bits, @magic_cookie::bytes, i::96>>}) do
    case Type.decode(t) do
      {:ok, class, method} ->
        {:ok, %{x | class: class, method: method, length: Length.decode(l), identifier: i}}
      {:error, _} = e ->
        e
    end
  end

  defp encode(type, length, identifier) do
    <<0::2, type::bits, length::bytes, @magic_cookie::bytes, identifier::bytes>>
  end
end
