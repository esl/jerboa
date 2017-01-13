defmodule Jerboa.Format.BodyTest do
  use ExUnit.Case, async: true
  alias Jerboa.Format.Body
  alias Jerboa.Format.Body.Attribute

  @identifier :crypto.strong_rand_bytes(div(96, 8))

  describe "Body.decode/1" do

    test "IPv4 XORMappedAddress attribute" do
      b = <<0x0020::16, 8::16, padding()::8, ip_4()::8, port()::16-bits, ip_4_addr()::32-bits>>

      assert {:ok, %Jerboa.Format{attributes: [x]}} = Body.decode(%Jerboa.Format{body: b, length: 12})
      assert x == %Attribute{
        name: Attribute.XORMappedAddress,
        value: %Attribute.XORMappedAddress{
          family: 4,
          address: {0,0,0,0},
          port: 0}}
    end

    test "IPv6 XORMappedAddress attribute" do
      b = <<0x0020::16, 20::16, padding()::8, ip_6()::8, port()::16-bits, ip_6_addr()::128-bits>>

      assert {:ok, %Jerboa.Format{attributes: [x]}} = Body.decode(%Jerboa.Format{identifier: @identifier, body: b, length: 24})
      assert x == %Attribute{
        name: Attribute.XORMappedAddress,
        value: %Attribute.XORMappedAddress{
          family: 6,
          address: {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
          port: 0}}
    end
  end

  describe "Body.Attribute.decode/1" do

    test "unknow comprehension required attribute results in :error tuple" do
      for x <- 0x0000..0x7FFF, not x in known() do
        assert {:error, %Attribute.ComprehensionRequiredError{attribute: x}} == Attribute.decode(%Jerboa.Format{}, x, <<>>)
      end
    end
  end

  defp padding, do: 0

  defp ip_4, do: 0x01

  defp ip_6, do: 0x02

  defp port do
    :crypto.exor(<<0::16>>, most_significant_magic_16())
  end

  defp ip_4_addr do
    :crypto.exor(<<0::32>>, magic_cookie())
  end

  defp ip_6_addr do
    :crypto.exor(<<0::128>>, magic_cookie() <> @identifier)
  end

  defp magic_cookie, do: <<0x2112A442 :: 32>>

  defp most_significant_magic_16 do
    <<x::16-bits, _::16>> = magic_cookie()
    x
  end

  defp known do
    [0x0020]
  end
end
