defmodule Jerboa.Format.BodyTest do
  use ExUnit.Case
  alias Jerboa.Format.Body
  alias Jerboa.Format.Body.Attribute

  @most_significant_magic_16 <<0x2112 :: 16>>

  describe "Body.decode/1" do

    test "exclusive or mapped address attribute" do
      use Bitwise
      p = :crypto.exor(<<0 :: 16>>, @most_significant_magic_16)
      ip_4 = :crypto.exor(<<0 :: 32>>, <<0x2112A442::32>>)
      b = <<0x0020::16, 8::16, 0::8, 0x01::8, p::16-bits, ip_4::32-bits>>
      assert %Jerboa.Format{attributes: [x]} = Body.decode(%Jerboa.Format{body: b})
      assert x == %Attribute{
        name: Attribute.XORMappedAddress,
        value: %Attribute.XORMappedAddress.IPAddress{
          family: 4,
          address: {0,0,0,0},
          port: 0}}
    end
  end
end
