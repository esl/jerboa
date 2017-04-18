defmodule Jerboa.Format.Body.Attribute.ChannelNumberTest do
  use ExUnit.Case
  use Quixir

  alias Jerboa.Format.Body.Attribute.ChannelNumber
  alias Jerboa.Format.Meta

  describe "encode/1" do

    test "CHANNEL-NUMBER attribute with a valid number" do
      min = ChannelNumber.min_number()
      max = ChannelNumber.max_number()
      ptest number: int(min: min, max: max) do
        assert <<number::16, 0::16>> == %ChannelNumber{number: number} |> ChannelNumber.encode()
      end
    end

    test "CHANNEL-NUMBER with an invalid/reserved number" do
      ## See TURN RFC for the invalid range:
      ## - https://tools.ietf.org/html/rfc5766#section-11
      ## - https://tools.ietf.org/html/rfc5766#section-14.1
      ptest number: int(min: 0x0000, max: 0x3FFF) do
        assert_raise FunctionClauseError, fn ->
          %ChannelNumber{number: number} |> ChannelNumber.encode()
        end
      end
      ptest number: int(min: 0x8000, max: 0xFFFF) do
        assert_raise FunctionClauseError, fn ->
          %ChannelNumber{number: number} |> ChannelNumber.encode()
        end
      end
    end

  end

  describe "decode/2" do

    test "accepts binaries starting with 0b01" do
      ptest number: int(min: 0b0100_0000_0000_0000, max: 0b0111_1111_1111_1111) do
        encoded = <<number::16, 0::16>>
        assert {:ok, _, %ChannelNumber{number: number}} = ChannelNumber.decode(encoded, %Meta{})
      end
    end

    test "rejects binaries starting with 0b00, 0b10, 0b11" do
      ptest number: int(min: 0b0, max: 0b0011_1111_1111_1111) do
        encoded = <<number::16, 0::16>>
        assert {:error, _} = ChannelNumber.decode(encoded, %Meta{})
      end
      ptest number: int(min: 0b1000_0000_0000_0000, max: 0b1111_1111_1111_1111) do
        encoded = <<number::16, 0::16>>
        assert {:error, _} = ChannelNumber.decode(encoded, %Meta{})
      end
    end

  end

  describe "decode/encode composition" do

    test "is an identity" do
      min = ChannelNumber.min_number()
      max = ChannelNumber.max_number()
      ptest number: int(min: min, max: max) do
        cn = %ChannelNumber{number: number}
        {:ok, _, new_cn} =
          cn
          |> ChannelNumber.encode()
          |> ChannelNumber.decode(%Meta{})
        assert cn === new_cn
      end
    end

  end

end
