defmodule Jerboa.Format.HeadTest do
  use ExUnit.Case
  alias Jerboa.Format.Head
  @i :crypto.strong_rand_bytes(div 96, 8)
  @struct %Jerboa.Format{class: :request, method: :binding, identifier: @i, body: <<>>}
  @binary Head.encode(@struct)

  describe "Head.encode/1" do

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

  describe "Head.decode/1" do

    test "header hasn't leading clear bits" do
      for b <- 0b01..0b11 do
        assert {:error, %Head.MostSignificant2BitsError{bits: b}} == Head.decode(%Jerboa.Format{head: <<b::2, any()::158-bits>>})
      end
    end

    test "(binding response) class and method from type" do
      i = @i
      h = <<0::2, 257::14, 8::16, 0x2112A442::32, i::96-bits>>
      assert {:ok,
              %Jerboa.Format{
                class: :success,
                method: :binding}} = Head.decode(%Jerboa.Format{head: h})
    end

    test "identifier is a 96 bit binary (not an integer)" do
      i = @i
      h = <<0::2, 257::14, 8::16, 0x2112A442::32, i::96-bits>>
      assert {:ok, %Jerboa.Format{identifier: ^i}} = Head.decode(%Jerboa.Format{head: h})
    end
  end

  describe "Head.*.encode/1" do

    test "bind request method and class in 14 bit type" do
      x = Head.Type.encode(%Jerboa.Format{class: :request, method: :binding})
      assert 14 === bit_size x
      assert <<0x0001::16>> == <<0::2, x::14-bits>>
    end

    test "length into 16 bits (two bytes)" do
      x = Head.Length.encode(%Jerboa.Format{body: <<0,1,0,1>>})
      assert 16 === bit_size x
      assert <<0, 4>> = x
    end
  end

  describe "Head.*.decode/1" do

    test "length into 16 bits (two bytes)" do
      for b <- 0b01..0b11 do
        assert {:error, %Head.Length.Last2BitsError{bits: b}} == Head.Length.decode(<<any()::14-bits, b::2>>)
      end
    end
  end

  defp any do
    :crypto.strong_rand_bytes(div(160, 8))
  end
end
