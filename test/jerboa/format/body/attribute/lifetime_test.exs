defmodule Jerboa.Format.Body.Attribute.LifetimeTest do
  use ExUnit.Case
  use Quixir

  alias Jerboa.Format.Body.Attribute.Lifetime
  alias Jerboa.Format.Lifetime.LengthError
  alias Jerboa.Format.Meta

  describe "decode/1" do
    test "LIFETIME attribute with valid length" do
      ptest duration: int(min: 0, max: Lifetime.max_duration) do
        lifetime = <<duration::32>>

        assert {:ok, _, %Lifetime{duration: ^duration}} =
          Lifetime.decode(lifetime, %Meta{})
      end
    end

    test "LIFETIME attribute with invalid length" do
      ptest length: int(min: 5) do
        lifetime = for _ <- 1..length, into: <<>>, do: <<Enum.random(0..255)>>

        assert {:error, %LengthError{length: ^length}} =
          Lifetime.decode(lifetime, %Meta{})
      end
    end
  end

  describe "encode/1" do
    test "LIFETIME attribute with valid value" do
      ptest duration: int(min: 0, max: Lifetime.max_duration) do
        assert <<duration::32>> == %Lifetime{duration: duration} |> Lifetime.encode()
      end
    end

    test "LIFETIME attribute with invalid value throws FunctionClauseError" do
      ptest duration: negative_int() do
        assert_raise FunctionClauseError, fn ->
          %Lifetime{duration: duration} |> Lifetime.encode()
        end
      end
    end
  end
end
