defmodule Jerboa.Format.Body.Attribute.LifetimeTest do
  use ExUnit.Case
  use Quixir

  alias Jerboa.Format.Body.Attribute.Lifetime
  alias Jerboa.Format.Lifetime.LengthError

  @max_duration :math.pow(2, 32) |> :erlang.trunc() |> Kernel.-(1)

  describe "decode/1" do
    test "LIFETIME attribute with valid length" do
      ptest duration: int(min: 0, max: @max_duration) do
        lifetime = <<duration::32>>

        assert {:ok, %Lifetime{duration: duration}} == Lifetime.decode(lifetime)
      end
    end

    test "LIFETIME attribute with invalid length" do
      ptest lifetime: string(min: 5, chars: :ascii) do
        length = byte_size(lifetime)

        assert {:error, %LengthError{length: ^length}} = Lifetime.decode(lifetime)
      end
    end
  end

  describe "encode/1" do
    test "LIFETIME attribute with valid value" do
      ptest duration: int(min: 0, max: @max_duration) do
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
