defmodule Jerboa.Format.Body.Attribute.XORMappedAddress do
  @moduledoc """

  Encode and decode the XORMappedAddress attribute.

  """

  alias Jerboa.Format.Body.Attribute
  import Bitwise
  @ip_4 <<0x01 :: 8>>
  @ip_6 <<0x02 :: 8>>
  @magic_cookie Jerboa.Format.Head.MagicCookie.value
  @most_significant_magic_16 @magic_cookie >>> 16

  defstruct [:family, :address, :port]

  defmodule InvalidFamily do
    defexception [:message, :number]

    def message(%__MODULE__{number: n}) do
      "IP family should be 4 or 6. Got 0x#{Integer.to_string(n, 16)} on the wire."
    end
  end

  defmodule InvalidLength do
    defexception [:message, :length]

    def message(%__MODULE__{}) do
      "Invalid value length. XOR Mapped Address attribute value" <>
      "must be 8 bytes or 20 bytes long for IPv4 and IPv6 respectively"
    end
  end

  def decode(_, <<_::8, @ip_4, p::16, a::32-bits>>) do
    {:ok, %Attribute{name: __MODULE__, value: %__MODULE__{family: 4, address: ip_4(a), port: port(p)}}}
  end
  def decode(%Jerboa.Format{identifier: i}, <<_::8, @ip_6, p::16, a::128-bits>>) do
    {:ok, %Attribute{name: __MODULE__, value: %__MODULE__{family: 6, address: ip_6(a, i), port: port(p)}}}
  end
  def decode(_, value) when byte_size(value) != 20 or byte_size(value) != 8 do
    {:error, InvalidLength.exception(length: byte_size(value))}
  end
  def decode(_, <<_::8, f::8, _::binary>>) do
    {:error, InvalidFamily.exception(number: f)}
  end

  defp port(x) do
    x ^^^ @most_significant_magic_16
  end

  defp ip_4(x) when 32 === bit_size(x) do
    <<a, b, c, d>> = :crypto.exor x, <<0x2112A442 :: 32>>
    {a, b, c, d}
  end

  defp ip_6(x, i) do
    <<a,b,c,d, e,f,g,h, i,j,k,l, m,n,o,p>> = :crypto.exor x, <<0x2112A442 :: 32>> <> i
    {a,b,c,d, e,f,g,h, i,j,k,l, m,n,o,p}
  end
end
