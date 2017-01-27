defmodule Jerboa.Format.Body.AttributeTest do
  use ExUnit.Case, async: true

  alias Jerboa.Test.Helper.XORMappedAddress, as: XORMAHelper
  alias Jerboa.Test.Helper.Attribute, as: AHelper

  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Params

  describe "Attribute.encode/2" do

    test "IPv4 XORMappedAddress as a TLV" do
      attr = XORMAHelper.struct(4)

      bin = Attribute.encode %Params{}, attr

      assert type(bin) === 0x0020
      assert length_(bin) === AHelper.total(address: 32, other: 32)
    end

    test "IPv6 XORMappedAddress as a TLV" do
      i = XORMAHelper.i()
      attr = XORMAHelper.struct(6)
      params = %Params{identifier: i}

      bin = Attribute.encode params, attr

      assert type(bin) === 0x0020
      assert length_(bin) === AHelper.total(address: 128, other: 32)
    end
  end

  defp type(<<x::16, _::binary>>), do: x

  defp length_(<<_::16, x::16, _::size(x)-bytes>>), do: 8 * x
end
