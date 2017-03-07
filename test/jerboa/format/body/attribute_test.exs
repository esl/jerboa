defmodule Jerboa.Format.Body.AttributeTest do
  use ExUnit.Case, async: true

  alias Jerboa.Test.Helper.XORMappedAddress, as: XORMAHelper

  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Format.Body.Attribute.{XORMappedAddress, Lifetime, Data, Nonce,
                                      Username, Realm, ErrorCode}
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

    test "NONCE as a TLV" do
      value = "12345"

      bin = Attribute.encode(Params.new, %Nonce{value: value})

      assert type(bin) == 0x0015
      assert length_correct?(bin, total(value: byte_size(value)))
    end

    test "USERNAME as a TLV" do
      value = "Hello"

      bin = Attribute.encode(Params.new, %Username{value: value})

      assert type(bin) == 0x0006
      assert length_correct?(bin, total(value: byte_size(value)))
    end

    test "REALM as a TLV" do
      value = "Super Server"

      bin = Attribute.encode(Params.new, %Realm{value: value})

      assert type(bin) == 0x0014
      assert length_correct?(bin, total(value: byte_size(value)))
    end

    test "ERROR-CODE as a TLV" do
      code = 400
      reason = "alice has a cat"

      bin = Attribute.encode(Params.new, %ErrorCode{code: code, reason: reason})

      assert type(bin) == 0x0009
      assert length_correct?(bin, total(padding_and_code: 4, reason: byte_size(reason)))
    end
  end

  describe "Attribute.decode/3 is opposite to encode/2 for" do
    test "XOR-MAPPED-ADDRESS" do
      attr = %XORMappedAddress{family: :ipv4, address: {0, 0, 0, 0}, port: 0}
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

    test "DATA" do
      attr = %Data{content: "Hello"}
      params = Params.new
      bin = Attribute.encode(params, attr)

      assert {:ok, attr} == Attribute.decode(params, 0x0013, value(bin))
    end

    test "NONCE" do
      attr = %Nonce{value: "12345"}
      params = Params.new
      bin = Attribute.encode(params, attr)

      assert {:ok, attr} == Attribute.decode(params, 0x0015, value(bin))
    end

    test "USERNAME" do
      attr = %Username{value: "Hello"}
      params = Params.new
      bin = Attribute.encode(params, attr)

      assert {:ok, attr} == Attribute.decode(params, 0x0006, value(bin))
    end

    test "REALM" do
      attr = %Realm{value: "Super Server"}
      params = Params.new
      bin = Attribute.encode(params, attr)

      assert {:ok, attr} == Attribute.decode(params, 0x0014, value(bin))
    end

    test "ERROR-CODE" do
      attr = %ErrorCode{code: 400, name: :bad_request}
      params = Params.new
      bin = Attribute.encode(params, attr)

      assert {:ok, ^attr} = Attribute.decode(params, 0x0009, value(bin))
    end
  end
end
