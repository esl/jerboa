defmodule Jerboa.Format.Body.Attrbute.EvenPortTest do
  use ExUnit.Case
  use Quixir

  alias Jerboa.Format.Body.Attribute.EvenPort
  alias Jerboa.Format.EvenPort.FormatError
  alias Jerboa.Format.Meta

  describe "decode/2" do
    test "EVEN-PORT attribute of invalid length" do
      ptest value: string(min: 2) do
        assert {:error, %FormatError{}} = EvenPort.decode(value, %Meta{})
      end
    end

    test "EVEN-PORT attribute of invalid format" do
      ptest first_bit: int(min: 0, max: 1), extra_bits: int(min: 1, max: 127) do
        value = <<first_bit::1, extra_bits::7>>

        assert {:error, %FormatError{}} = EvenPort.decode(value, %Meta{})
      end
    end

    test "EVEN-PORT attribute with reserved bit set to 1" do
      value = <<1::1, 0::7>>

      assert {:ok, _, %EvenPort{reserved?: true}} =
        EvenPort.decode(value, %Meta{})
    end

    test "EVEN-PORT attribute with reserved bit set to 0" do
      value = <<0::1, 0::7>>

      assert {:ok, _, %EvenPort{reserved?: false}} =
        EvenPort.decode(value, %Meta{})
    end
  end

  describe "encode/1" do
    test "EVEN-PORT attribute with `:reserved?` set to false" do
      assert <<0::1, 0::7>> == %EvenPort{reserved?: false} |> EvenPort.encode()
    end

    test "EVEN-PORT attribute with `:reserved?` set to true" do
      assert <<1::1, 0::7>> == %EvenPort{reserved?: true} |> EvenPort.encode()
    end

    test "EVEN-PORT attribute with invalid `:reserved?` value" do
      assert_raise FunctionClauseError, fn ->
          %EvenPort{reserved?: "hi"} |> EvenPort.encode()
        end
    end
  end
end
