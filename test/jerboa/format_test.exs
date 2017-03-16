defmodule Jerboa.FormatTest do
  use ExUnit.Case, async: true
  use Quixir

  alias Jerboa.Test.Helper.XORMappedAddress, as: XORMAHelper

  alias Jerboa.{Format, Params}
  alias Format.{HeaderLengthError, BodyLengthError}
  alias Jerboa.Format.Header.MagicCookie

  @magic MagicCookie.value

  describe "Format.encode/1" do

    test "body follows header with length in header" do

      ## Given:
      import Jerboa.Test.Helper.Header, only: [identifier: 0]
      a = XORMAHelper.struct(4)

      ## When:
      bin = Format.encode %Params{
        class: :success,
        method: :binding,
        identifier: identifier(),
        attributes: [a]}

      ## Then:
      assert Jerboa.Test.Helper.Format.bytes_for_body(bin) == 12
    end
  end

  describe "Format.decode/1" do

    test "fails given packet with not enough bytes for header" do
      ptest length: int(min: 0, max: 19), content: int(min: 0) do
        byte_length = length * 8
        packet = <<content::size(byte_length)>>

        assert {:error, %HeaderLengthError{binary: ^packet}} = Format.decode packet
      end
    end

    test "fails given packet with too short message body" do
      ptest method: int(min: 1, max: 1), class: int(min: 0, max: 3),
            length: int(min: 1000), body: int(min: 0),
            body_length: int(min: 0, max: ^length - 1) do
        <<c1::1, c0::1>> = <<class::2>>
        <<m2::5, m1::3, m0::4>> = <<method::12>>
        type = <<m2::5, c1::1, m1::3, c0::1, m0::4>>
        packet = <<0::2, type::bits, length::16, @magic::32, 0::96,
                   body::unit(8)-size(body_length)>>

        {:error, error} = Format.decode packet

        assert %BodyLengthError{length: ^body_length} = error
      end
    end

    test "returns bytes after the length given in the header into the `extra` field" do
      ptest method: int(min: 1, max: 1), class: int(min: 0, max: 3),
        extra: string(min: 1) do
        <<c1::1, c0::1>> = <<class::2>>
        <<m2::5, m1::3, m0::4>> = <<method::12>>
        type = <<m2::5, c1::1, m1::3, c0::1, m0::4>>
        packet = <<0::2, type::bits, 0::16, @magic::32, 0::96,
          extra::binary>>

        assert {:ok, _, ^extra} = Format.decode packet
      end
    end
  end

  describe "Format.decode!/1" do
    test "raises an exception upon failure" do
      packet = "Supercalifragilisticexpialidocious!"

      assert_raise Jerboa.Format.First2BitsError, fn -> Format.decode!(packet) end
    end

    test "returns value without an :ok tuple" do
      packet = <<0::2, 1::14, 0::16, @magic::32, 0::96>>

      assert %Params{} = Format.decode!(packet)
    end
  end
end
