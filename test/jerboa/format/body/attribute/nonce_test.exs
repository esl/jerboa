defmodule Jerboa.Format.Body.Attribute.NonceTest do
  use ExUnit.Case
  use Quixir

  alias Jerboa.Format.Body.Attribute.Nonce
  alias Jerboa.Format.Nonce.LengthError

  describe "decode/1" do
    test "NONCE attribute of valid length" do
      ptest value: string(max: Nonce.max_chars) do
        assert {:ok, %Nonce{value: value}} == Nonce.decode(value)
      end
    end

    test "NONCE attribute of invalid length" do
      length = Nonce.max_chars + 1
      value = String.duplicate("a", length)

      assert {:error, %LengthError{length: ^length}} = Nonce.decode(value)
    end
  end

  describe "encode/1" do
    test "NONCE attribute with string value of valid length" do
      ptest value: string(max: Nonce.max_chars) do
        assert value == %Nonce{value: value} |> Nonce.encode()
      end
    end

    test "NONCE attribute with string value of invalid length" do
      value = String.duplicate("a", Nonce.max_chars + 1)

      assert_raise ArgumentError, fn ->
        %Nonce{value: value} |> Nonce.encode()
      end
    end

    test "NONCE attribute with non-string value" do
      assert_raise ArgumentError, fn ->
        %Nonce{value: 1} |> Nonce.encode()
      end
    end
  end
end
