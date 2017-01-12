defmodule Jerboa.Format.Head do
  @moduledoc """

  Encode and decode headers for the STUN wire format.

  """

  alias Jerboa.Format.Head.{Type,Length,MagicCookie,Identifier}

  @magic_cookie MagicCookie.encode

  defmodule MostSignificant2BitsError do
    defexception [:message, :bits]

    def message(%__MODULE__{}) do
      "the most significant two bits of a STUN message must be zeros"
    end
  end

  def encode(params) do
    t = Type.encode(params)
    l = Length.encode(params)
    i = Identifier.encode(params)
    encode t, l, i
  end

  def decode(x = %Jerboa.Format{head: <<0::2, t::14-bits, l::16-bits, @magic_cookie::bytes, i::96>>}) do
    with {:ok, class, method} <- Type.decode(t),
         {:ok, length}        <- Length.decode(l) do
      {:ok, %{x | class: class, method: method, length: length, identifier: i}}
    else
      {:error, _} = e ->
        e
    end
  end
  def decode(%Jerboa.Format{head: <<b::2, _::158>>}) do
    {:error, MostSignificant2BitsError.exception(bits: b)}
  end

  defp encode(type, length, identifier) do
    <<0::2, type::bits, length::bytes, @magic_cookie::bytes, identifier::bytes>>
  end
end
