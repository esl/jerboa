defmodule Jerboa.Format.Body.Attribute.ReservationTokenTest do
  use ExUnit.Case
  use Quixir

  alias Jerboa.Format.Body.Attribute.ReservationToken
  alias Jerboa.Format.ReservationToken.LengthError
  alias Jerboa.Format.Meta

  describe "decode/2" do
    test "RESERVATION-TOKEN with length less than 8 bytes" do
      ptest length: int(min: 0, max: 7), content: int(min: 0) do
        value = <<content::size(length)-unit(8)>>

        assert {:error, %LengthError{length: ^length}} =
          ReservationToken.decode(value, %Meta{})
      end
    end

    test "RESERVATION-TOKEN with length more than 8 bytes" do
      ptest length: int(min: 9), content: int(min: 0) do
        value = <<content::size(length)-unit(8)>>

        assert {:error, %LengthError{length: ^length}} =
          ReservationToken.decode(value, %Meta{})
      end
    end

    test "valid, 8 bytes long RESERVATION-TOKEN" do
      ptest content: int(min: 0) do
        value = <<content::size(8)-unit(8)>>

        assert {:ok, _, %ReservationToken{value: ^value}} =
          ReservationToken.decode(value, %Meta{})
      end
    end
  end

  describe "encode/1" do
    test "RESERVATION-TOKEN with valid value" do
      ptest content: int(min: 0) do
        value = <<content::size(8)-unit(8)>>

        assert value ==
          %ReservationToken{value: value} |> ReservationToken.encode()
      end
    end

    test "RESERVATION-TOKEN with invalid value" do
      assert_raise FunctionClauseError, fn ->
        %ReservationToken{value: 123} |> ReservationToken.encode()
      end
    end
  end
end
