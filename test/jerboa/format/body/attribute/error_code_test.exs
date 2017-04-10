defmodule Jerboa.Format.Body.Attribute.ErrorCodeTest do
  use ExUnit.Case
  use Quixir

  alias Jerboa.Format.Body.Attribute.ErrorCode
  alias Jerboa.Format.ErrorCode.{FormatError, LengthError}
  alias Jerboa.Format.Meta

  describe "encode/1" do
    test "ERROR-CODE attribute with valid error code and reason" do
      ptest reason: string(max: ErrorCode.max_reason_length) do
        code = random_code()

        bin = binary_attr(code, reason)
        assert bin == %ErrorCode{code: code, reason: reason} |> ErrorCode.encode()
      end
    end

    test "ERROR-CODE attribute with valid error name and reason" do
      ptest reason: string(max: ErrorCode.max_reason_length) do
        name = random_name()

        assert <<0::21, _::11, ^reason::binary>> =
          %ErrorCode{name: name, reason: reason} |> ErrorCode.encode()
      end
    end

    test "ERROR-CODE with non UTF-8 binary as reason" do
      reason = <<0xFFFF>>
      code = random_code()

      assert_raise ArgumentError, fn ->
        %ErrorCode{code: code, reason: reason} |> ErrorCode.encode()
      end
    end

    test "ERROR-CODE with invalid error code" do
      assert_raise ArgumentError, fn ->
        %ErrorCode{code: 1, reason: "alice has a cat"} |> ErrorCode.encode()
      end
    end

    test "ERROR-CODE with invalid error name" do
      assert_raise ArgumentError, fn ->
        %ErrorCode{name: :not_an_error, reason: "alice has a cat"} |> ErrorCode.encode()
      end
    end
  end

  describe "decode/1" do
    test "ERROR-CODE shorter than 4 bytes" do
      ptest length: int(min: 0, max: 3), content: int(min: 0) do
        bin = <<content::size(length)-unit(8)>>

        assert {:error, %LengthError{length: ^length}} = ErrorCode.decode(bin, %Meta{})
      end
    end

    test "ERROR-CODE with non UTF-8 reason" do
      code = random_code()
      reason = <<0xFFFF>>
      bin = binary_attr(code, reason)

      assert {:error, error} = ErrorCode.decode(bin, %Meta{})
      assert %FormatError{} = error
      assert error.code == code
      assert error.reason == reason
    end

    test "ERROR-CODE with invalid error code" do
      code = 123
      reason = "alice has a cat"
      bin = binary_attr(code, reason)

      assert {:error, error} = ErrorCode.decode(bin, %Meta{})
      assert %FormatError{} = error
      assert error.code == code
      assert error.reason == reason
    end

    test "valid ERROR-CODE attribute" do
      ptest reason: string(max: ErrorCode.max_reason_length) do
        code = random_code()

        bin = binary_attr(code, reason)

        assert {:ok, _, attr} = ErrorCode.decode(bin, %Meta{})
        assert attr.code == code
        assert attr.name
        assert attr.reason == reason
      end
    end
  end

  describe "new/1" do
    test "returns filled in struct given valid error code" do
      code = 400

      assert %ErrorCode{name: :bad_request, code: code} == ErrorCode.new(code)
    end

    test "returns filled in struct given valid error name" do
      name = :bad_request

      assert %ErrorCode{name: name, code: 400} == ErrorCode.new(name)
    end

    test "raises on invalid error code" do
      assert_raise FunctionClauseError, fn ->
        ErrorCode.new(801)
      end
    end

    test "raises on invalid error name" do
      assert_raise FunctionClauseError, fn ->
        ErrorCode.new(:not_a_valid_error)
      end
    end
  end

  defp binary_attr(code, reason) do
    <<0::21, class(code)::3, number(code)::8, reason::binary>>
  end

  defp class(code), do: div(code, 100)

  defp number(code), do: rem(code, 100)

  defp random_code, do: ErrorCode.valid_codes() |> Enum.random()

  defp random_name, do: ErrorCode.valid_names() |> Enum.random()
end
