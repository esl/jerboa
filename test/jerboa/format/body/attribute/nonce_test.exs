defmodule Jerboa.Format.Body.Attribute.NonceTest do
  use ExUnit.Case
  use Quixir

  alias Jerboa.Format.Body.Attribute.Nonce

  test "decode/1 DATA attribute" do
    ptest value: string() do
      assert {:ok, %Nonce{value: value}} == Nonce.decode(value)
    end
  end

  describe "encode/1" do
    test "DATA attribute with binary value" do
      ptest value: string() do
        assert value == %Nonce{value: value} |> Nonce.encode()
      end
    end

    test "DATA attribute with non-binary value" do
      assert_raise FunctionClauseError, fn ->
        %Nonce{value: 1} |> Nonce.encode()
      end
    end
  end

end
