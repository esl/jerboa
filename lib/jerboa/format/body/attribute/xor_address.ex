defmodule Jerboa.Format.Body.Attribute.XORAddress do
  @moduledoc false

  ## Functions for decoding and decoding XOR-*-ADDRESS attributes

  use Bitwise

  alias Jerboa.Format.Body.Attribute.{XORMappedAddress, XORPeerAddress,
                                      XORRelayedAddress}
  alias Jerboa.Format.XORAddress.{LengthError, IPFamilyError, IPArityError}
  alias Jerboa.Format.Meta
  alias Jerboa.Params

  @type t :: XORMappedAddress.t | XORPeerAddress.t | XORRelayedAddress.t

  @ipv4 <<0x01::8>>
  @ipv6 <<0x02::8>>
  @magic_cookie Jerboa.Format.Header.MagicCookie.value
  @most_significant_magic_16 @magic_cookie >>> 16

  defmacro __using__(type_code: type_code) do
    quote do
      defstruct [:family, :address, :port]

      @type t :: %__MODULE__{
        family: :ipv4 | :ipv6,
        address: :inet.ip_address,
        port: :inet.port_number
      }

      defimpl Jerboa.Format.Body.Attribute.Encoder do
        def type_code(_), do: unquote(type_code)

        def encode(attr, meta) do
          value =
            Jerboa.Format.Body.Attribute.XORAddress.encode(attr, meta.params)
          {meta, value}
        end
      end

      defimpl Jerboa.Format.Body.Attribute.Decoder do
        def decode(attr, value, meta) do
          Jerboa.Format.Body.Attribute.XORAddress.decode(attr, value, meta)
        end
      end
    end
  end

  @spec encode(t, Params.t) :: binary
  def encode(%{family: :ipv4, address: a, port: p}, _params) do
    encode(@ipv4, ipv4_encode(a), p)
  end
  def encode(%{family: :ipv6, address: a, port: p}, %Params{identifier: i}) do
    encode(@ipv6, ipv6_encode(a, i), p)
  end

  @spec decode(t, value :: binary, Meta.t)
    :: {:ok, Meta.t, t} | {:error, struct}
  def decode(attr, <<_::8, @ipv4, port::16, addr::32-bits>>, meta) do
    {:ok, meta, attribute(attr, addr, port)}
  end
  def decode(attr, <<_::8, @ipv6, port::16, addr::128-bits>>,
    %Meta{params: %Params{identifier: id}} = meta) do
    {:ok, meta, attribute(attr, addr, port, id)}
  end
  def decode(_, value, _) when byte_size(value) != 20 and byte_size(value) != 8 do
    {:error, LengthError.exception(length: byte_size(value))}
  end
  def decode(_, <<_::8, f::8-bits, _::16, _::binary>>, _) when f == @ipv4 or f == @ipv6 do
    {:error, IPArityError.exception(family: f)}
  end
  def decode(_, <<_::8, f::8, _::binary>>, _) do
    {:error, IPFamilyError.exception(number: f)}
  end

  defp encode(family, addr, port) do
    <<0::8, family::8-bits, port(port)::16, addr::binary>>
  end

  defp ipv4_encode(addr) when tuple_size(addr) === 4 do
    addr |> binerize |> ipv4_decode |> binerize
  end

  defp ipv6_encode(addr, id) when tuple_size(addr) === 8 do
    addr |> binerize |> ipv6_decode(id) |> binerize
  end

  defp ipv4_decode(x_addr) when 32 === bit_size(x_addr) do
    <<a, b, c, d>> = :crypto.exor x_addr, <<@magic_cookie::32>>
    {a, b, c, d}
  end

  defp ipv6_decode(x_addr, id) do
    <<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>> =
      :crypto.exor(x_addr, <<@magic_cookie::32>> <> id)
    {a, b, c, d, e, f, g, h}
  end

  defp attribute(attr, x_addr, x_port) do
    struct attr, %{
      family: :ipv4,
      address: ipv4_decode(x_addr),
      port: port(x_port)
    }
  end

  defp attribute(attr, x_addr, x_port, id) do
    struct attr, %{
      family: :ipv6,
      address: ipv6_decode(x_addr, id),
      port: port(x_port)
    }
  end

  defp port(x_port) do
    x_port ^^^ @most_significant_magic_16
  end

  defp binerize({a, b, c, d}) do
    <<a, b, c, d>>
  end
  defp binerize({a, b, c, d, e, f, g, h}) do
    <<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>>
  end
end
