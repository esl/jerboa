defmodule Jerboa.Format.Body.AttributeTest do
  use ExUnit.Case, async: true
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute

  describe "Attribute.encode/2" do

    test "IPv4 XORMappedAddress as a TLV" do
      f = :ipv4
      a = {0, 0, 0, 0}
      p = 0
      attr = %Attribute.XORMappedAddress{family: f, address: a, port: p}

      bin = Attribute.encode %Format{}, attr

      assert <<0x0020::16, 8::16, _::64>> = bin
    end

    test "IPv6 XORMappedAddress as a TLV" do
      f = :ipv6
      a = {0,0,0,0 ,0,0,0,0, 0,0,0,0, 0,0,0,0}
      p = 0
      i = :crypto.strong_rand_bytes(div(96, 8))
      attr = %Attribute.XORMappedAddress{family: f, address: a, port: p}
      params = %Format{identifier: i}

      bin = Attribute.encode params, attr

      assert <<0x0020::16, 20::16, _::160>> = bin
    end
  end
end
