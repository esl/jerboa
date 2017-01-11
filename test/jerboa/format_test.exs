defmodule Jerboa.FormatTest do
  use ExUnit.Case
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute
  @i :crypto.strong_rand_bytes(div 96, 8)
  @most_significant_magic_16 <<0x2112 :: 16>>

  describe "Format.encode/1" do

    test "bind request" do
      i = @i
      want = <<0::2, 1::14, 0::16, 0x2112A442::32, i::96-bits>>
      got = Format.encode %Jerboa.Format{
        class: :request,
        method: :binding,
        identifier: @i,
        body: <<>>}
      assert want == got
    end
  end

  describe "Format.decode/1" do

    test "bind response" do
      i = @i
      p = :crypto.exor(<<0 :: 16>>, @most_significant_magic_16)
      ip_4 = :crypto.exor(<<0 :: 32>>, <<0x2112A442::32>>)
      a = <<0x0020::16, 8::16, 0::8, 0x01::8, p::16-bits, ip_4::32-bits>>
      got = Jerboa.Format.decode(<<0::2, 257::14, 8::16, 0x2112A442::32, i::96-bits, a::binary>>)
      assert %Jerboa.Format{
        class: :success,
        method: :binding,
        attributes: [x]} = got
      assert %Attribute{
        name: Attribute.XORMappedAddress,
        value: %Attribute.XORMappedAddress.IPAddress{
          family: 4,
          address: {0,0,0,0},
          port: 0}} == x
    end
  end
end
