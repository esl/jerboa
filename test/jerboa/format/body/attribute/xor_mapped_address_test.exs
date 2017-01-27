defmodule Jerboa.Format.Body.Attribute.XORMappedAddressTest do
  use ExUnit.Case
  use Quixir

  alias Jerboa.Test.Helper.XORMappedAddress, as: XORMAHelper

  alias Jerboa.Format.XORMappedAddress.{IPFamilyError, LengthError, IPArityError}
  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Format.Body.Attribute.XORMappedAddress
  alias Jerboa.Format.Header.MagicCookie
  alias Jerboa.Params

  describe "decode/2" do
    test "IPv4 XORMappedAddress attribute" do
      ptest port: port_gen(), ip_addr: ip4_gen() do
        x_ip_addr = x_ip4_addr(ip_addr)
        x_port = x_port(port)
        attr = <<padding()::8, ip_4()::8, x_port::16-bits, x_ip_addr::32-bits>>
        body = <<0x0020::16, 8::16, attr::binary>>

        result = XORMappedAddress.decode(%Params{body: body, length: 12}, attr)

        assert {:ok, %Attribute{name: XORMappedAddress, value: val}} = result
        assert val == %XORMappedAddress{
                        family: :ipv4,
                        address: ip_addr,
                        port: port}
      end
    end

    test "IPv6 XORMappedAddress attribute" do
      ptest port: port_gen(), ip_addr: ip6_gen(), id: int(min: 0) do
        identifier = <<id::96>>
        x_ip_addr = x_ip6_addr(ip_addr, identifier)
        x_port = x_port(port)
        attr = <<padding()::8, ip_6()::8, x_port::16-bits, x_ip_addr::128-bits>>
        body = <<0x0020::16, 20::16, attr::binary>>

        result = XORMappedAddress.decode(%Params{identifier: identifier,
                                                 body: body, length: 24}, attr)

        assert {:ok, %Attribute{name: XORMappedAddress, value: val}} = result
        assert val == %XORMappedAddress{
                        family: :ipv6,
                        address: ip_addr,
                        port: port}
      end
    end

    test "fails when attribute's value has invalid length" do
      ptest length: int(min: 9, max: 19), content: int(min: 0) do
        bit_length = length * 8
        attr = <<content::size(bit_length)>>
        body = <<0x0020::16, length::16, attr::binary>>

        {:error, error} = XORMappedAddress.decode(%Params{body: body,
                                                          length: byte_size(body)}, attr)

        assert %LengthError{length: ^length} = error
      end
    end

    test "fails when address family is invalid" do
      ptest family: int(min: 3, max: 255), content: int(min: 0) do
        length = Enum.random([20, 8])
        # the length of attribute value minu first zeroed byte and family
        content_length = length * 8 - 16
        attr = <<padding()::8, family::8, content::size(content_length)>>
        body = <<0x0020::16, length::16, attr::binary>>

        {:error, error} = XORMappedAddress.decode(%Params{body: body,
                                                          length: byte_size(body)}, attr)

        assert %IPFamilyError{number: ^family} = error
      end
    end

    test "fails when address does not match family" do
      for {family, addr_len} <- [{0x01, 128}, {0x02, 32}] do
        attr = <<padding()::8, family::8, 0::16, 0::size(addr_len)>>
        body = <<0x0020::16, byte_size(attr)::16, attr::binary>>

        {:error, error} = XORMappedAddress.decode(%Params{body: body,
                                                          length: byte_size(body)}, attr)
        assert %IPArityError{family: <<^family::8>>} = error
      end
    end
  end

  describe "XORMappedAddress.encode/1" do

    test "IPv4" do
      attr = XORMAHelper.struct(4)

      bin = XORMappedAddress.encode(%Params{}, attr)

      assert address_family(bin) === "IPv4"
      assert address_bits(bin) === 32
      assert x_port_number(bin) === XORMAHelper.port()
      assert x_address(bin) == XORMAHelper.ip_4_a()
    end

    test "IPv6" do
      i = XORMAHelper.i()
      attr = XORMAHelper.struct(6)
      params = %Params{identifier: i}

      bin = XORMappedAddress.encode(params, attr)

      assert address_family(bin) === "IPv6"
      assert address_bits(bin) === 128
      assert x_port_number(bin) === XORMAHelper.port()
      assert x_address(bin, i) == XORMAHelper.ip_6_a()
    end
  end

  defp padding, do: 0

  defp ip_4, do: 0x01

  defp ip_6, do: 0x02

  defp x_port(port) do
    :crypto.exor(<<port::16>>, most_significant_magic_16())
  end

  defp x_ip4_addr({a3, a2, a1, a0}) do
    :crypto.exor(<<a3::8, a2::8, a1::8, a0::8>>, MagicCookie.encode())
  end

  defp x_ip6_addr(ip6_addr, identifier) do
    {a, b, c, d, e, f, g, h} = ip6_addr
    bin_addr = <<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>>
    :crypto.exor(bin_addr, MagicCookie.encode() <> identifier)
  end

  defp most_significant_magic_16 do
    <<x::16-bits, _::16>> = MagicCookie.encode()
    x
  end

  defp port_gen do
    int(min: 0, max: 65_535)
  end

  defp ip4_gen do
    tuple(like: :erlang.make_tuple(4, byte()))
  end

  defp ip6_gen do
    tuple(like: :erlang.make_tuple(8, two_bytes()))
  end

  defp byte do
    int(min: 0, max: 255)
  end

  defp two_bytes do
    int(min: 0, max: 65_535)
  end

  defp address_family(<<_::8, 0x01::8, _::binary>>), do: "IPv4"
  defp address_family(<<_::8, 0x02::8, _::binary>>), do: "IPv6"

  defp address_bits(<<_::32, a::binary>>), do: bit_size(a)

  defp x_port_number(<<_::16, p::16-bits, _::binary>>) do
    <<x::16>> = :crypto.exor(p, most_significant_magic_16())
    x
  end

  defp x_address(<<_::32, a::32-bits>>) do
    <<a, b, c, d>> = :crypto.exor(a, MagicCookie.encode())
    {a, b, c, d}
  end

  defp x_address(<<_::32, a::128-bits>>, identifier) do
    <<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>> =
      :crypto.exor(a, MagicCookie.encode() <> identifier)
    {a, b, c, d, e, f, g, h}
  end
end
