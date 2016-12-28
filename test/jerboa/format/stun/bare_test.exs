defmodule Jerboa.Format.STUN.BareTest do
  use ExUnit.Case
  use Quixir

  alias Jerboa.Format.STUN.Bare

  describe "decode/1" do
    test "fails given packet with not enough bytes for header" do
      ptest length: int(min: 0, max: 159), content: int(min: 0) do
        packet = <<content::size(length)>>

        assert {:error, _} = Bare.decode packet
      end
    end

    test "fails given packet not starting with two zeroed bits" do
      ptest first_two: int(min: 1, max: 3), content: int(min: 0),
            length: int(min: 20) do
        bit_length = length * 8 - 2
        packet = <<first_two::2, content::size(bit_length)>>

        assert {:error, _} = Bare.decode packet
      end
    end

    test "fails given packet with invalid STUN magic cookie" do
      ptest before_magic: int(min: 0), magic: int(min: 0),
            after_magic: int(min: 0), length: int(min: 12) do
        packet = <<0::2, before_magic::30, magic::32,
                   after_magic::unit(8)-size(length)>>

        assert {:error, _} = Bare.decode packet
      end
    end

    test "extracts method and decodes class from the packet" do
      ptest method: int(min: 0), class: int(min: 0, max: 3), t_id: int(min: 0),
            length: int(min: 0), body: int(min: 0) do
        <<c1::1, c0::1>> = <<class::2>>
        <<m2::5, m1::3, m0::4>> = <<method::12>>
        magic = Jerboa.Format.STUN.magic
        packet = <<0::2, m2::5, c1::1, m1::3, c0::1, m0::4, length::16,
                   magic::32, t_id::96, body::size(length)-unit(8)>>

        {:ok, bare} = Bare.decode packet
        decoded_class = Jerboa.Format.STUN.class_from_integer(class)

        assert method == bare.method
        assert decoded_class == bare.class
      end
    end
  end
end
