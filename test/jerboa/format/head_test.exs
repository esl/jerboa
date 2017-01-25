defmodule Jerboa.Format.HeaderTest do
  use ExUnit.Case, async: true

  alias Jerboa.Format.Header
  alias Jerboa.Format.{First2BitsError,
    MagicCookieError, UnknownMethodError, Last2BitsError}
  alias Jerboa.Format.Header.{MagicCookie, Type.Method, Type.Class}
  alias Jerboa.Format.Header
  alias Jerboa.Params
  use Quixir

  @magic MagicCookie.value

  describe "Header.encode/1" do

    test "header has all five pieces (and reasonable values)" do

      ## Given:
      alias Jerboa.Test.Helper.Format, as: FormatHelper
      parameters = FormatHelper.binding_request()

      ## When:
      %Jerboa.Format{header: bin} = Header.encode(parameters)

      ## Then:
      assert byte_size(bin) === 20
      assert first_2_bits(bin) === <<0::2>>
      assert type(bin) === 1
      assert body_bytes(bin) === 0
      assert magic_cookie(bin) === 0x2112A442
      assert identifier(bin) === parameters.identifier
    end
  end

  describe "Header.decode/1" do

    test "fails given packet not starting with two zeroed bits" do
      ptest first_two: int(min: 1, max: 3), content: int(min: 0) do
        bit_length = 20 * 8 - 2
        packet = <<first_two::2, content::size(bit_length)>>

        {:error, error} = Header.decode parameterize(packet)

        assert %First2BitsError{bits: ^first_two} = error
      end
    end

    test "fails given packet with invalid STUN magic cookie" do
      ptest before_magic: int(min: 0), magic: int(min: 0, max: @magic - 1),
            after_magic: int(min: 0) do
        packet = <<0::2, before_magic::30, magic::32,
                   after_magic::unit(8)-size(12)>>
        <<header::20-bytes, _::binary>> = packet

        {:error, error} = Header.decode parameterize(packet)

        assert %MagicCookieError{header: ^header} = error
      end
    end

    test "fails if length isn't a multiple of 4" do
      ptest length: int(min: 0) do
        length = if rem(length, 4) == 0, do: length + 1, else: length
        packet = <<0::2, 1::14, length::16, @magic::32, 0::96>>

        {:error, error} = Header.decode parameterize(packet)

        assert %Last2BitsError{length: ^length} = error
      end
    end

    test "fails given packet with invalid STUN method" do
      ptest method: int(min: 1024, max: 4095), class: int(min: 0, max: 3) do
        <<c1::1, c0::1>> = <<class::2>>
        <<m2::5, m1::3, m0::4>> = <<method::12>>
        packet = <<0::2, m2::5, c1::1, m1::3, c0::1, m0::4, 0::16,
                   @magic::32, 0::96>>

        {:error, error} = Header.decode parameterize(packet)

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

        {:ok, message} = Header.decode parameterize(packet)

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

  defp parameterize(x) do
    %Jerboa.Format{header: x}
  end

  defp first_2_bits(<<x::2-bits, _::bits>>) do
    x
  end

  defp type(<<_::2, x::14, _::144>>) do
    x
  end

  defp body_bytes(<<_::16, x::16, _::128>>) do
    x
  end

  defp magic_cookie(<<_::32, x::32, _::96>>) do
    x
  end

  defp identifier(<<_::64, x::96-bits>>) do
    x
  end
end
