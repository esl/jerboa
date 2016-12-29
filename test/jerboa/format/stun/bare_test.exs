defmodule Jerboa.Format.STUN.BareTest do
  use ExUnit.Case, async: true
  use Quixir

  alias Jerboa.Format.STUN.Bare

  describe "decode/1" do
    test "fails given packet with not enough bytes for header" do
      ptest length: int(min: 0, max: 159), content: int(min: 0) do
        packet = <<content::size(length)>>

        assert {:error, "Invalid header length"} = Bare.decode packet
      end
    end

    test "fails given packet not starting with two zeroed bits" do
      ptest first_two: int(min: 1, max: 3), content: int(min: 0),
            length: int(min: 20) do
        bit_length = length * 8 - 2
        packet = <<first_two::2, content::size(bit_length)>>

        assert {:error, "First two bits of STUN packet should be zeroed"} = Bare.decode packet
      end
    end

    test "fails given packet with invalid STUN magic cookie" do
      ptest before_magic: int(min: 0), magic: int(min: 0),
            after_magic: int(min: 0), length: int(min: 12) do
        packet = <<0::2, before_magic::30, magic::32,
                   after_magic::unit(8)-size(length)>>

        assert {:error, "Invalid STUN magic cookie"} = Bare.decode packet
      end
    end

    test "extracts method and decodes class from the packet" do
      ptest method: int(min: 0), class: int(min: 0, max: 3),
            t_id: int(min: 0) do
        <<c1::1, c0::1>> = <<class::2>>
        <<m2::5, m1::3, m0::4>> = <<method::12>>
        magic = Jerboa.Format.STUN.magic
        packet = <<0::2, m2::5, c1::1, m1::3, c0::1, m0::4, 0::16,
                   magic::32, t_id::96>>

        {:ok, bare} = Bare.decode packet
        decoded_class = Jerboa.Format.STUN.class_from_integer(class)

        assert method == bare.method
        assert decoded_class == bare.class
      end
    end

    test "fails given packet with too short message body" do
      ptest type: int(min: 0), t_id: int(min: 0), length: int(min: 1000),
            body: int(min: 0), body_length: int(min: 0, max: ^length - 1) do
        magic = Jerboa.Format.STUN.magic
        packet = <<0::2, type::14, length::16, magic::32, t_id::96,
                   body::unit(8)-size(body_length)>>

        assert {:error, "Invalid message body length"} = Bare.decode packet
      end
    end

    test "extracts attributes from message body" do
      ptest type: int(min: 0), t_id: int(min: 0),
            attrs: list(of: tuple(like: {int(min: 0), string()})) do
        bin_attrs = encode_attributes(attrs)
        packet = create_packet(type, t_id, bin_attrs)

        {:ok, bare} = Bare.decode packet

        assert attrs == bare.attrs
      end
    end

    test "fails if body does not have enough bytes for attribute" do
      ptest type: int(min: 0), t_id: int(min: 0), extra: int(min: 1, max: 3),
            attrs: list(of: tuple(like: {int(min: 0), string()})) do
        bin_attrs = encode_attributes(attrs)
        bin_attrs = <<bin_attrs::binary, 1::size(extra)-unit(8)>>
        packet = create_packet(type, t_id, bin_attrs)

        assert {:error, "Not enough bytes for attribute"} = Bare.decode packet
      end
    end

    test "fails if there are not enough bytes for attribute value" do
      ptest type: int(min: 0), t_id: int(min: 0), attr_length: int(min: 0),
            attr_type: int(min: 0), attr_value: int() do
        bin_attr = <<attr_type::16, (attr_length + 1)::16,
                     attr_value::size(attr_length)-unit(8)>>
        packet = create_packet(type, t_id, bin_attr)

        assert {:error, "Not enough bytes for attribute value"} = Bare.decode packet
      end
    end

    test "fails if there is no attribute padding" do
      ptest type: int(min: 0), t_id: int(min: 0), attr_type: int(min: 0),
            attr_value: int(), attr_length: int(min: 0) do
        attr_length =
          if rem(attr_length, 4) == 0, do: attr_length + 1, else: attr_length
        bin_attr = <<attr_type::16, attr_length::16,
                     attr_value::size(attr_length)-unit(8)>>
        packet = create_packet(type, t_id, bin_attr)

        assert {:error, "No attribute padding"} = Bare.decode packet
      end
    end
  end

  ## Test helpers

  defp calculate_padding(length) do
    case rem(length, 4) do
      0 -> 0
      n -> 4 - n
    end
  end

  defp create_packet(type, t_id, body) do
    length = byte_size(body)
    magic = Jerboa.Format.STUN.magic
    header = <<0::2, type::14, length::16, magic::32, t_id::96>>
    <<header::binary, body::binary>>
  end

  defp encode_attributes(attrs) do
    Enum.map(attrs, fn {type, value} ->
      length = byte_size(value)
      pad_len = calculate_padding(length)
      <<type::16, length::16, value::binary, 0::size(pad_len)-unit(8)>>
    end)
    |> Enum.join()
  end
end
