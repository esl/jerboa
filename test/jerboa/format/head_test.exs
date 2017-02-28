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
  @helpers [first_2_bits: 1,
            type: 1,
            magic_cookie: 1,
            identifier: 1
           ]

  describe "Header.encode/1" do

    test "header has all five pieces (and reasonable values)" do

      ## Given:
      import Jerboa.Test.Helper.Header, only: @helpers
      alias Jerboa.Test.Helper.Format, as: FormatHelper
      parameters = FormatHelper.binding_request()

      ## When:
      %Jerboa.Params{header: bin} = Header.encode(parameters)

      ## Then:
      assert byte_size(bin) === 20
      assert first_2_bits(bin) === <<0::2>>
      assert type(bin) === 1
      assert FormatHelper.bytes_for_body(bin) === 0
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

  test "Header.Length.encode/1 encodes length on 16 bits (two bytes)" do
    x = Header.Length.encode(%Params{body: <<0,1,0,1>>})

    assert <<4::size(16)>> == x
  end

  test "Header.Type encode/1 and decode/1 return opposite results" do
    allowed = [binding: [:request, :success, :failure],
               allocate: [:request, :success, :failure],
               refresh: [:request, :success, :failure],
               create_permission: [:request, :success, :failure],
               send: [:indication],
               data: [:indication]]

    for {method, classes} <- allowed do
      for class <- classes do
        params = %Params{class: class, method: method}

        bin = Header.Type.encode(params)

        assert {:ok, ^class, ^method} = Header.Type.decode(bin)
      end
    end
  end

  defp parameterize(x) do
    %Jerboa.Params{header: x}
  end
end
