defmodule Jerboa.Format.Body.AttributeTest do
  use ExUnit.Case, async: true

  alias Jerboa.Test.Helper.XORMappedAddress, as: XORMAHelper

  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Format.Body.Attribute.{Lifetime, Data}
  alias Jerboa.Params

  import Jerboa.Test.Helper.Attribute, only: [total: 1, length_correct?: 2,
                                              type: 1, value: 1]

  describe "Attribute.encode/2" do

    test "IPv4 XORMappedAddress as a TLV" do
      attr = XORMAHelper.struct(4)

      bin = Attribute.encode %Params{}, attr

      assert type(bin) === 0x0020
      assert length_correct?(bin, total(address: 4, other: 4))
    end

    test "IPv6 XORMappedAddress as a TLV" do
      i = XORMAHelper.i()
      attr = XORMAHelper.struct(6)
      params = %Params{identifier: i}

      bin = Attribute.encode params, attr

      assert type(bin) === 0x0020
      assert length_correct?(bin, total(address: 16, other: 4))
    end

    test "LIFETIME as a TLV" do
      duration = 12_345

      bin = Attribute.encode(Params.new, %Lifetime{duration: duration})

      assert type(bin) == 0x000D
      assert length_correct?(bin, total(duration: 4))
    end

    test "DATA as a TLV" do
      content = "Hello"

      bin = Attribute.encode(Params.new, %Data{content: content})

      assert type(bin) == 0x0013
      assert length_correct?(bin, total(content: byte_size(content)))
    end
  end

  describe "Attribute.decode/3 is opposite to encode/2 for" do
    test "XOR-MAPPED-ADDRESS" do
      attr = XORMAHelper.struct(4)
      params = Params.new
      bin = Attribute.encode(params, attr)

      assert {:ok, attr} == Attribute.decode(params, 0x0020, value(bin))
    end

    test "LIFETIME" do
      attr = %Lifetime{duration: 12_345}
      params = Params.new
      bin = Attribute.encode(params, attr)

      assert {:ok, attr} == Attribute.decode(params, 0x000D, value(bin))
    end

    test "Data" do
      attr = %Data{content: "Hello"}
      params = Params.new
      bin = Attribute.encode(params, attr)

      assert {:ok, attr} == Attribute.decode(params, 0x0013, value(bin))
    end
  end
end
