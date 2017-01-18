defmodule Jerboa.Format.Body.Attribute.XORMappedAddress do
  @moduledoc """
  XOR Mapped Address attribute as defined in the [STUN
  RFC](https://tools.ietf.org/html/rfc5389#section-15.2)
  """

  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Format.XORMappedAddress.{LengthError,IPFamilyError,IPArityError}
  import Bitwise
  @ip_4 <<0x01::8>>
  @ip_6 <<0x02::8>>
  @magic_cookie Jerboa.Format.Header.MagicCookie.value
  @most_significant_magic_16 @magic_cookie >>> 16

  defstruct [:family, :address, :port]
  @typedoc """
  A client's reflexive transport address
  """
  @type t :: %__MODULE__{
    family: :ipv4 | :ipv6,
    address: :inet.ip_address,
    port: :inet.port_number
  }

  @doc false
  @spec encode(Jerboa.Format.t, t) :: binary
  def encode(_, %__MODULE__{family: :ipv4, address: a, port: p}) do
    encode(@ip_4, ip_4_encode(a), p)
  end
  def encode(%Jerboa.Format{identifier: i}, %__MODULE__{family: :ipv6, address: a, port: p}) do
    encode(@ip_6, ip_6_encode(a, i), p)
  end

  @doc false
  @spec decode(params :: Jerboa.Format.t, value :: binary) :: {:ok, Attribute.t}
                                                            | {:error, struct}
  def decode(_, <<_::8, @ip_4, p::16, a::32-bits>>) do
    {:ok, %Attribute{name: __MODULE__, value: attribute(a, p)}}
  end
  def decode(%Jerboa.Format{identifier: i}, <<_::8, @ip_6, p::16, a::128-bits>>) do
    {:ok, %Attribute{name: __MODULE__, value: attribute(a, p, i)}}
  end
  def decode(_, value) when byte_size(value) != 20 and byte_size(value) != 8 do
    {:error, LengthError.exception(length: byte_size(value))}
  end
  def decode(_, <<_::8, f::8-bits, _::16, _::binary>>) when f == @ip_4 or f == @ip_6 do
    {:error, IPArityError.exception(family: f)}
  end
  def decode(_, <<_::8, f::8, _::binary>>) do
    {:error, IPFamilyError.exception(number: f)}
  end

  defp encode(f, a, p) do
    <<0::8, f::8-bits, port(p)::16, a::binary>>
  end

  defp attribute(a, p) do
    %__MODULE__{
      family: :ipv4,
      address: ip_4_decode(a),
      port: port(p)
    }
  end

  defp attribute(a, p, i) do
    %__MODULE__{
      family: :ipv6,
      address: ip_6_decode(a, i),
      port: port(p)
    }
  end

  defp port(x) do
    x ^^^ @most_significant_magic_16
  end

  defp ip_4_decode(x) when 32 === bit_size(x) do
    <<a, b, c, d>> = :crypto.exor x, <<0x2112A442::32>>
    {a, b, c, d}
  end

  defp ip_4_encode(x) when tuple_size(x) === 4 do
    x |> binerize |> ip_4_decode |> binerize
  end

  defp ip_6_encode(x, i) when tuple_size(x) === 16 do
    x |> binerize |> ip_6_decode(i) |> binerize
  end

  defp ip_6_decode(x, i) do
    <<a,b,c,d, e,f,g,h, i,j,k,l, m,n,o,p>> = :crypto.exor x, <<0x2112A442::32>> <> i
    {a,b,c,d, e,f,g,h, i,j,k,l, m,n,o,p}
  end

  defp binerize({a, b, c, d}) do
    <<a, b, c, d>>
  end
  defp binerize({a,b,c,d, e,f,g,h, i,j,k,l, m,n,o,p}) do
    <<a,b,c,d, e,f,g,h, i,j,k,l, m,n,o,p>>
  end
end
