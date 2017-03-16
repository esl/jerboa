defmodule Jerboa.Format.Body.Attribute.RequestedTransportTest do
  use ExUnit.Case
  use Quixir

  alias Jerboa.Format.Body.Attribute.RequestedTransport
  alias Jerboa.Format.RequestedTransport.{LengthError, ProtocolError}
  alias Jerboa.Format.Meta

  describe "decode/2" do
    test "REQUESTED-TRANSPORT with valid length and protocol" do
      ptest rest: int(min: 0) do
        proto_code = Enum.random RequestedTransport.known_protocol_codes
        value = <<proto_code::8, rest::24>>

        assert {:ok, _, %RequestedTransport{}} =
          RequestedTransport.decode(value, %Meta{})
      end
    end

    test "REQUESTED-TRANSPORT with valid length and invalid protocol" do
      proto_code = 1
      value = <<proto_code::8, 0::24>>

      assert {:error, %ProtocolError{protocol_code: ^proto_code}} =
        RequestedTransport.decode(value, %Meta{})
    end

    test "REQUESTED-TRANSPORT with invalid length" do
      proto_code = Enum.random RequestedTransport.known_protocol_codes
      value = <<proto_code::8, 0::8>>
      length = byte_size(value)

      assert {:error, %LengthError{length: ^length}} =
        RequestedTransport.decode(value, %Meta{})
    end
  end

  describe "encode/1" do
    test "REQUESTED-TRANSPORT with valid protocol" do
      proto = Enum.random RequestedTransport.known_protocols

      assert %RequestedTransport{protocol: proto} |> RequestedTransport.encode()
    end

    test "REQUESTED-TRANSPORT with invalid protocol" do
      proto = :tcp

      assert_raise ArgumentError, fn ->
        %RequestedTransport{protocol: proto} |> RequestedTransport.encode()
      end
    end
  end
end
