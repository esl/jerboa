defmodule Jerboa.Format.BodyTest do
  use ExUnit.Case
  alias Jerboa.Format.Body
  alias Jerboa.Format.Body.Attribute

  @most_significant_magic_16 <<0x2112 :: 16>>

  describe "Body.decode/1" do

    test "IPv4 XORMappedAddress attribute" do
      use Bitwise
      p = :crypto.exor(<<0 :: 16>>, @most_significant_magic_16)
      ip_4 = :crypto.exor(<<0 :: 32>>, <<0x2112A442::32>>)
      b = <<0x0020::16, 8::16, 0::8, 0x01::8, p::16-bits, ip_4::32-bits>>
      assert {:ok, %Jerboa.Format{attributes: [x]}} = Body.decode(%Jerboa.Format{body: b})
      assert x == %Attribute{
        name: Attribute.XORMappedAddress,
        value: %Attribute.XORMappedAddress{
          family: 4,
          address: {0,0,0,0},
          port: 0}}
    end

    test "IPv6 XORMappedAddress attribute" do
      p = :crypto.exor(<<0 :: 16>>, @most_significant_magic_16)
      i = :crypto.strong_rand_bytes(div 96, 8)
      ip_6 = :crypto.exor(<<0 :: 128>>, <<0x2112A442::32>> <> i)
      b = <<0x0020::16, 20::16, 0::8, 0x02::8, p::16-bits, ip_6::128-bits>>
      assert {:ok, %Jerboa.Format{attributes: [x]}} = Body.decode(%Jerboa.Format{identifier: i, body: b})
      assert x == %Attribute{
        name: Attribute.XORMappedAddress,
        value: %Attribute.XORMappedAddress{
          family: 6,
          address: {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
          port: 0}}
    end
  end
end
