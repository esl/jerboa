defmodule Jerboa.Format.Body.AttributeTest do
  use ExUnit.Case, async: true

  alias Jerboa.Test.Helper.XORMappedAddress, as: XORMAHelper

  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute

  describe "Attribute.encode/2" do

    test "IPv4 XORMappedAddress as a TLV" do
      attr = XORMAHelper.struct(4)

      bin = Attribute.encode %Format{}, attr

      assert <<0x0020::16, 8::16, _::64>> = bin
    end

    test "IPv6 XORMappedAddress as a TLV" do
      attr = XORMAHelper.struct(6)
      params = %Format{identifier: XORMAHelper.i()}

      bin = Attribute.encode params, attr

      assert <<0x0020::16, 20::16, _::160>> = bin
    end
  end
end
