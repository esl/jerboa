defmodule Jerboa.Format.HeaderTest do
  use ExUnit.Case, async: true

  alias Jerboa.Format.Header
  alias Jerboa.Format.{First2BitsError, MagicCookieError, UnknownMethodError, Last2BitsError}
  alias Jerboa.Format.Header.{MagicCookie, Type.Method, Type.Class}
  alias Jerboa.Format.Header
  alias Jerboa.Params
  use Quixir

  @i :crypto.strong_rand_bytes(div 96, 8)
  @struct %Params{class: :request, method: :binding, identifier: @i, body: <<>>}
  @binary Map.fetch!(Header.encode(@struct), :header)
  @magic MagicCookie.value

  describe "Header.encode/1" do

    test "header is correct length" do
      assert 20 === byte_size @binary
    end

    test "two leading clear bits" do
      assert <<0::2, _::14, _::16, _::32, _::96>> = @binary
    end

    test "(bind request) method and class type in correct place" do
      assert <<_::2, 1::14, _::16, _::32, _::96>> = @binary
    end

    test "correct body length in correct place" do
      assert <<_::2, _::14, 0::16, _::32, _::96>> = @binary
    end

    test "magic cookie in correct place" do
      assert <<_::2, _::14, _::16, 0x2112A442::32, _::96>> = @binary
    end

    test "correct identifier in correct place" do
      i = @i
      assert <<_::2, _::14, _::16, _::32, ^i::96-bits>> = @binary
    end
  end

  describe "Header.decode/1" do

    test "fails given packet not starting with two zeroed bits" do
      ptest first_two: int(min: 1, max: 3), content: int(min: 0),
            length: int(min: 20) do
        bit_length = length * 8 - 2
        packet = <<first_two::2, content::size(bit_length)>>

        {:error, error} = Jerboa.Format.decode packet

        assert %First2BitsError{bits: ^first_two} = error
      end
    end

    test "fails given packet with invalid STUN magic cookie" do
      ptest before_magic: int(min: 0), magic: int(min: 0, max: @magic - 1),
            after_magic: int(min: 0), length: int(min: 12) do
        packet = <<0::2, before_magic::30, magic::32,
                   after_magic::unit(8)-size(length)>>
        <<header::20-bytes, _::binary>> = packet

        {:error, error} = Jerboa.Format.decode packet

        assert %MagicCookieError{header: ^header} = error
      end
    end

    test "fails if length isn't a multiple of 4" do
      ptest length: int(min: 0), content: int(min: 0) do
        length = if rem(length, 4) == 0, do: length + 1, else: length
        packet = <<0::2, 1::14, length::16, @magic::32, 0::96,
                  content::size(length)-unit(8)>>

        {:error, error} = Jerboa.Format.decode packet

        assert %Last2BitsError{length: ^length} = error
      end
    end

    test "fails given packet with invalid STUN method" do
      ptest method: int(min: 1024, max: 4095), class: int(min: 0, max: 3) do
        <<c1::1, c0::1>> = <<class::2>>
        <<m2::5, m1::3, m0::4>> = <<method::12>>
        packet = <<0::2, m2::5, c1::1, m1::3, c0::1, m0::4, 0::16,
                   @magic::32, 0::96>>

        {:error, error} = Jerboa.Format.decode packet

        assert %UnknownMethodError{method: ^method} = error
      end
    end

    test "decodes class and method from the header" do
      ptest method: int(min: 1, max: 1), class: int(min: 0, max: 3) do
        bit_class = <<c1::1, c0::1>> = <<class::2>>
        bit_method = <<m2::5, m1::3, m0::4>> = <<method::12>>
        packet = <<0::2, m2::5, c1::1, m1::3, c0::1, m0::4, 0::16,
          @magic::32, 0::96>>
        decoded_class = Class.decode(bit_class)
        {:ok, decoded_method} = Method.decode(bit_method)

        {:ok, message} = Jerboa.Format.decode packet

        assert decoded_method == message.method
        assert decoded_class == message.class
      end
    end
  end

  describe "Header.*.encode/1" do

    test "bind request method and class in 14 bit type" do
      x = Header.Type.encode(%Params{class: :request, method: :binding})

      assert 14 === bit_size x
      assert <<0x0001::16>> == <<0::2, x::14-bits>>
    end

    test "length into 16 bits (two bytes)" do
      x = Header.Length.encode(%Params{body: <<0,1,0,1>>})

      assert 16 === bit_size x
      assert <<0, 4>> = x
    end

    test "binding success response" do
      params = %Params{class: :success, method: :binding}

      bin = Header.Type.encode(params)

      assert <<4, 1::6>> == bin
    end
  end

  describe "Header.*.decode/1" do

    test "binding request" do
      assert {:ok, :request, :binding} == Header.Type.decode <<0::6, 1>>
    end
  end
end
