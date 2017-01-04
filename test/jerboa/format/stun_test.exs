defmodule Jerboa.Format.STUNTest do
  use ExUnit.Case
  doctest Jerboa.Format.STUN

  alias Jerboa.Format.STUN
  alias STUN.{Bare, DecodeError}

  describe "decode/1" do
    test "fails when class and method of message are incompatible" do
      packet = %Bare{class: :indication, method: 3, t_id: 0} |> Bare.encode()

      {:error, %DecodeError{method: error_msg}} = STUN.decode(packet)

      assert "method allocate is not allowed with class indication" = error_msg
    end
  end
end
