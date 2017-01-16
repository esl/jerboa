defmodule Jerboa.Format.Header do
  @moduledoc false

  alias Jerboa.Format.Header.{Type,Length,MagicCookie,Identifier}

  @magic_cookie MagicCookie.encode

  defmodule First2BitsError do
    defexception [:message, :bits]

    def message(%__MODULE__{}) do
      "the most significant two bits of a STUN message must be zeros"
    end
  end

  defmodule MagicCookieError do
    defexception [:message, :header]

    def message(%__MODULE__{}) do
      "STUN message doesn't have magic cookie"
    end
  end

  def encode(params) do
    t = Type.encode(params)
    l = Length.encode(params)
    i = Identifier.encode(params)
    encode t, l, i
  end

  def decode(x = %Jerboa.Format{header: <<0::2, t::14-bits, l::16-bits, @magic_cookie::bytes, i::96-bits>>}) do
    with {:ok, class, method} <- Type.decode(t),
         {:ok, length}        <- Length.decode(l) do
      {:ok, %{x | class: class, method: method, length: length, identifier: i}}
    else
      {:error, _} = e ->
        e
    end
  end
  def decode(%Jerboa.Format{header: <<0::2, _::30, _::128>> = header}) do
    {:error, MagicCookieError.exception(header: header)}
  end
  def decode(%Jerboa.Format{header: <<b::2, _::158>>}) do
    {:error, First2BitsError.exception(bits: b)}
  end

  defp encode(type, length, identifier) do
    <<0::2, type::bits, length::bytes, @magic_cookie::bytes, identifier::bytes>>
  end
end
