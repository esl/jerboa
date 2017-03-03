defmodule Jerboa.Format.Body.Attribute.UsernameTest do
  use ExUnit.Case
  use Quixir

  alias Jerboa.Format.Body.Attribute.Username
  alias Jerboa.Format.Username.LengthError

  describe "decode/1" do
    test "USERNAME attribute of valid length" do
      ptest value: string(max: Username.max_length, chars: :ascii) do
        assert {:ok, %Username{value: value}} == Username.decode(value)
      end
    end

    test "USERNAME attribute of invalid length" do
      length = Username.max_length + 1
      value = String.duplicate("a", length)

      assert {:error, %LengthError{length: ^length}} = Username.decode(value)
    end
  end

  describe "encode/1" do
    test "USERNAME attribute with string value of valid length" do
      ptest value: string(max: Username.max_length, chars: :ascii) do
        assert value == %Username{value: value} |> Username.encode()
      end
    end

    test "USERNAME attribute with string value of invalid length" do
      value = String.duplicate("a", Username.max_length + 1)

      assert_raise ArgumentError, fn ->
        %Username{value: value} |> Username.encode()
      end
    end

    test "USERNAME attibute with non valid UTF-8 binary" do
      value = <<0xFFFF>>

      assert_raise ArgumentError, fn ->
        %Username{value: value} |> Username.encode()
      end
    end

    test "USERNAME attribute with non-string value" do
      assert_raise ArgumentError, fn ->
        %Username{value: 1} |> Username.encode()
      end
    end
  end
end
