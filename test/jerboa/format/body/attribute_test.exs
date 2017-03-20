defmodule Jerboa.Format.Body.AttributeTest do
  use ExUnit.Case, async: true

  alias Jerboa.Test.Helper.XORMappedAddress, as: XORMAHelper

  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Format.Body.Attribute.{XORMappedAddress, Lifetime, Data, Nonce,
                                      Username, Realm, ErrorCode,
                                      XORPeerAddress, XORRelayedAddress,
                                      RequestedTransport}
  alias Jerboa.Params
  alias Jerboa.Format.Meta

  import Jerboa.Test.Helper.Attribute, only: [total: 1, length_correct?: 2,
                                              type: 1, value: 1]

  describe "Attribute.encode/2" do

    test "IPv4 XORMappedAddress as a TLV" do
      attr = XORMAHelper.struct(4)
      meta = %Meta{params: Params.new}

      {_, bin} = Attribute.encode meta, attr

      assert type(bin) === 0x0020
      assert length_correct?(bin, total(address: 4, other: 4))
    end

    test "IPv6 XORMappedAddress as a TLV" do
      i = XORMAHelper.i()
      attr = XORMAHelper.struct(6)
      params = %Params{identifier: i}
      meta = %Meta{params: params}

      {_, bin} = Attribute.encode meta, attr

      assert type(bin) === 0x0020
      assert length_correct?(bin, total(address: 16, other: 4))
    end

    test "LIFETIME as a TLV" do
      duration = 12_345
      meta = %Meta{params: Params.new}

      {_, bin} = Attribute.encode(meta, %Lifetime{duration: duration})

      assert type(bin) == 0x000D
      assert length_correct?(bin, total(duration: 4))
    end

    test "DATA as a TLV" do
      content = "Hello"
      meta = %Meta{params: Params.new}

      {_, bin} = Attribute.encode(meta, %Data{content: content})

      assert type(bin) == 0x0013
      assert length_correct?(bin, total(content: byte_size(content)))
    end

    test "NONCE as a TLV" do
      value = "12345"
      meta = %Meta{params: Params.new}

      {_, bin} = Attribute.encode(meta, %Nonce{value: value})

      assert type(bin) == 0x0015
      assert length_correct?(bin, total(value: byte_size(value)))
    end

    test "USERNAME as a TLV" do
      value = "Hello"
      meta = %Meta{params: Params.new}

      {_, bin} = Attribute.encode(meta, %Username{value: value})

      assert type(bin) == 0x0006
      assert length_correct?(bin, total(value: byte_size(value)))
    end

    test "REALM as a TLV" do
      value = "Super Server"
      meta = %Meta{params: Params.new}

      {_, bin} = Attribute.encode(meta, %Realm{value: value})

      assert type(bin) == 0x0014
      assert length_correct?(bin, total(value: byte_size(value)))
    end

    test "ERROR-CODE as a TLV" do
      code = 400
      reason = "alice has a cat"
      meta = %Meta{params: Params.new}

      {_, bin} = Attribute.encode(meta, %ErrorCode{code: code, reason: reason})

      assert type(bin) == 0x0009
      assert length_correct?(bin, total(padding_and_code: 4, reason: byte_size(reason)))
    end

    test "IPv4 XORPeerAddress as a TLV" do
      attr = %XORPeerAddress{port: 0, address: {0, 0, 0, 0}, family: :ipv4}
      meta = %Meta{params: Params.new()}

      {_, bin} = Attribute.encode meta, attr

      assert type(bin) === 0x0012
      assert length_correct?(bin, total(address: 4, other: 4))
    end

    test "IPv6 XORPeerAddress as a TLV" do
      attr = %XORPeerAddress{port: 0, address: {0, 0, 0, 0, 0, 0, 0, 0},
                             family: :ipv6}
      meta = %Meta{params: Params.new()}

      {_, bin} = Attribute.encode meta, attr

      assert type(bin) === 0x0012
      assert length_correct?(bin, total(address: 16, other: 4))
    end

    test "IPv4 XORRelayedAddress as a TLV" do
      attr = %XORRelayedAddress{port: 0, address: {0, 0, 0, 0}, family: :ipv4}
      meta = %Meta{params: Params.new()}

      {_, bin} = Attribute.encode meta, attr

      assert type(bin) === 0x0016
      assert length_correct?(bin, total(address: 4, other: 4))
    end

    test "IPv6 XORRelayedAddress as a TLV" do
      attr = %XORRelayedAddress{port: 0, address: {0, 0, 0, 0, 0, 0, 0, 0},
                                family: :ipv6}
      meta = %Meta{params: Params.new()}

      {_, bin} = Attribute.encode meta, attr

      assert type(bin) === 0x0016
      assert length_correct?(bin, total(address: 16, other: 4))
    end

    test "REQUESTED-TRANPOSRT as a TLV" do
      attr = %RequestedTransport{protocol: :udp}

      {_, bin} = Attribute.encode %Meta{}, attr

      assert type(bin) == 0x0019
      assert length_correct?(bin, total(protocol: 1, rffu: 3))
    end
  end

  describe "Attribute.decode/3 is opposite to encode/2 for" do
    test "XOR-MAPPED-ADDRESS" do
      attr = %XORMappedAddress{family: :ipv4, address: {0, 0, 0, 0}, port: 0}
      meta = %Meta{params: Params.new}

      {_, bin} = Attribute.encode(meta, attr)

      assert {:ok, _, ^attr} = Attribute.decode(meta, 0x0020, value(bin))
    end

    test "LIFETIME" do
      attr = %Lifetime{duration: 12_345}
      meta = %Meta{params: Params.new}

      {_, bin} = Attribute.encode(meta, attr)

      assert {:ok, _, ^attr} = Attribute.decode(meta, 0x000D, value(bin))
    end

    test "DATA" do
      attr = %Data{content: "Hello"}
      meta = %Meta{params: Params.new}

      {_, bin} = Attribute.encode(meta, attr)

      assert {:ok, _, ^attr} = Attribute.decode(meta, 0x0013, value(bin))
    end

    test "NONCE" do
      attr = %Nonce{value: "12345"}
      meta = %Meta{params: Params.new}

      {_, bin} = Attribute.encode(meta, attr)

      assert {:ok, _, ^attr} = Attribute.decode(meta, 0x0015, value(bin))
    end

    test "USERNAME" do
      attr = %Username{value: "Hello"}
      meta = %Meta{params: Params.new}

      {_, bin} = Attribute.encode(meta, attr)

      assert {:ok, _, ^attr} = Attribute.decode(meta, 0x0006, value(bin))
    end

    test "REALM" do
      attr = %Realm{value: "Super Server"}
      meta = %Meta{params: Params.new}

      {_, bin} = Attribute.encode(meta, attr)

      assert {:ok, _, ^attr} = Attribute.decode(meta, 0x0014, value(bin))
    end

    test "ERROR-CODE" do
      attr = %ErrorCode{code: 400, name: :bad_request}
      meta = %Meta{params: Params.new}

      {_, bin} = Attribute.encode(meta, attr)

      assert {:ok, _, ^attr} = Attribute.decode(meta, 0x0009, value(bin))
    end

    test "XOR-PEER-ADDRESS" do
      attr = %XORPeerAddress{family: :ipv4, address: {0, 0, 0, 0}, port: 0}
      meta = %Meta{params: Params.new}

      {_, bin} = Attribute.encode(meta, attr)

      assert {:ok, _, ^attr} = Attribute.decode(meta, 0x0012, value(bin))
    end

    test "XOR-RELAYED-ADDRESS" do
      attr = %XORRelayedAddress{family: :ipv4, address: {0, 0, 0, 0}, port: 0}
      meta = %Meta{params: Params.new}

      {_, bin} = Attribute.encode(meta, attr)

      assert {:ok, _, ^attr} = Attribute.decode(meta, 0x0016, value(bin))
    end

    test "REQUESTED-TRANSPORT" do
      attr = %RequestedTransport{protocol: :udp}
      meta = %Meta{}

      {_, bin} = Attribute.encode(meta, attr)

      assert {:ok, _, ^attr} = Attribute.decode(meta, 0x0019, value(bin))
    end
  end
end
