defmodule Jerboa.Format.Body.Attribute.XORMappedAddressTest do
  use ExUnit.Case
  use Quixir

  alias Jerboa.Format
  alias Jerboa.Format.XORMappedAddress.{IPFamilyError, LengthError, IPArityError}
  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Format.Body.Attribute.XORMappedAddress
  alias Jerboa.Format.Header.MagicCookie

  describe "decode/2" do
    test "IPv4 XORMappedAddress attribute" do
      ptest port: port_gen(), ip_addr: ip4_gen() do
        x_ip_addr = x_ip4_addr(ip_addr)
        x_port = x_port(port)
        attr = <<padding()::8, ip_4()::8, x_port::16-bits, x_ip_addr::32-bits>>
        body = <<0x0020::16, 8::16, attr::binary>>

        result = XORMappedAddress.decode(%Format{body: body, length: 12}, attr)

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

        result = XORMappedAddress.decode(%Format{identifier: identifier,
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

        {:error, error} = XORMappedAddress.decode(%Format{body: body,
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

        {:error, error} = XORMappedAddress.decode(%Format{body: body,
                                                          length: byte_size(body)}, attr)

        assert %IPFamilyError{number: ^family} = error
      end
    end

    test "fails when address does not match family" do
      for {family, addr_len} <- [{0x01, 128}, {0x02, 32}] do
        attr = <<padding()::8, family::8, 0::16, 0::size(addr_len)>>
        body = <<0x0020::16, byte_size(attr)::16, attr::binary>>

        {:error, error} = XORMappedAddress.decode(%Format{body: body,
                                                          length: byte_size(body)}, attr)
        assert %IPArityError{family: <<^family::8>>} = error
      end
    end
  end

  describe "XORMappedAddress.encode/1" do

    test "IPv4" do
      f = :ipv4
      a = {0, 0, 0, 0}
      p = 0
      attr = %XORMappedAddress{family: f, address: a, port: p}

      b = XORMappedAddress.encode(%Jerboa.Format{}, attr)

      assert b == <<padding()::8, ip_4()::8, x_port(p)::16-bits, x_ip4_addr(a)::32-bits>>
    end

    test "IPv6" do
      f =  :ipv6
      a = {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0}
      p = 0
      i = :crypto.strong_rand_bytes(div(96, 8))
      attr = %XORMappedAddress{family: f, address: a, port: p}
      params = %Jerboa.Format{identifier: i}

      b = XORMappedAddress.encode(params, attr)

      assert b == <<padding()::8, ip_6()::8, x_port(p)::16-bits, x_ip6_addr(a, i)::128-bits>>
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
    bin_addr = ip6_addr |> Tuple.to_list() |> :erlang.list_to_binary()
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
    tuple(like: :erlang.make_tuple(16, byte()))
  end

  defp byte do
    int(min: 0, max: 255)
  end
end
