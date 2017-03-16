defmodule Jerboa.Format.Body.Attribute.XORMappedAddress do
  @moduledoc """
  XOR Mapped Address attribute as defined in the [STUN
  RFC](https://tools.ietf.org/html/rfc5389#section-15.2)
  """

  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Format.Body.Attribute.{Decoder,Encoder}
  alias Jerboa.Format.XORMappedAddress.{LengthError,IPFamilyError,IPArityError}
  alias Jerboa.Params
  alias Jerboa.Format.Meta

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

  defimpl Encoder do
    alias Jerboa.Format.Body.Attribute.XORMappedAddress
    @type_code 0x0020

    @spec type_code(XORMappedAddress.t) :: integer
    def type_code(_attr), do: @type_code

    @spec encode(XORMappedAddress.t, Meta.t) :: {Meta.t, binary}
    def encode(attr, meta) do
      {meta, XORMappedAddress.encode(attr, meta.params)}
    end
  end

  defimpl Decoder  do
    alias Jerboa.Format.Body.Attribute.XORMappedAddress

    @spec decode(XORMappedAddress.t, value :: binary, meta :: Meta.t)
      :: {:ok, Meta.t, XORMappedAddress.t} | {:error, struct}
    def decode(_, value, meta), do: XORMappedAddress.decode(value, meta)
  end

  @doc false
  @spec encode(t, Params.t) :: binary
  def encode(%__MODULE__{family: :ipv4, address: a, port: p}, _params) do
    encode(@ip_4, ip_4_encode(a), p)
  end
  def encode(%__MODULE__{family: :ipv6, address: a, port: p},
    %Params{identifier: i}) do
    encode(@ip_6, ip_6_encode(a, i), p)
  end

  @doc false
  @spec decode(value :: binary, Meta.t) :: {:ok, Attribute.t} | {:error, struct}
  def decode(<<_::8, @ip_4, port::16, addr::32-bits>>, meta) do
    {:ok, meta, attribute(addr, port)}
  end
  def decode(<<_::8, @ip_6, port::16, addr::128-bits>>,
    %Meta{params: %Params{identifier: id}} = meta) do
    {:ok, meta, attribute(addr, port, id)}
  end
  def decode(value, _) when byte_size(value) != 20 and byte_size(value) != 8 do
    {:error, LengthError.exception(length: byte_size(value))}
  end
  def decode(<<_::8, f::8-bits, _::16, _::binary>>, _) when f == @ip_4 or f == @ip_6 do
    {:error, IPArityError.exception(family: f)}
  end
  def decode(<<_::8, f::8, _::binary>>, _) do
    {:error, IPFamilyError.exception(number: f)}
  end

  defp encode(family, addr, port) do
    <<0::8, family::8-bits, port(port)::16, addr::binary>>
  end

  defp attribute(x_addr, x_port) do
    %__MODULE__{
      family: :ipv4,
      address: ip_4_decode(x_addr),
      port: port(x_port)
    }
  end

  defp attribute(x_addr, x_port, id) do
    %__MODULE__{
      family: :ipv6,
      address: ip_6_decode(x_addr, id),
      port: port(x_port)
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

  defp ip_6_encode(x, i) when tuple_size(x) === 8 do
    x |> binerize |> ip_6_decode(i) |> binerize
  end

  defp ip_6_decode(x, i) do
    <<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>> =
      :crypto.exor(x, <<0x2112A442::32>> <> i)
    {a, b, c, d, e, f, g, h}
  end

  defp binerize({a, b, c, d}) do
    <<a, b, c, d>>
  end
  defp binerize({a, b, c, d, e, f, g, h}) do
    <<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>>
  end
end
