defmodule Jerboa.FormatTest do
  use ExUnit.Case, async: true
  use Quixir

  alias Jerboa.Test.Helper.XORMappedAddress, as: XORMAHelper

  alias Jerboa.{Format, Params}
  alias Format.{HeaderLengthError, BodyLengthError, First2BitsError,
                ChannelDataLengthError}
  alias Jerboa.Format.Header.MagicCookie
  alias Jerboa.Format.Body.Attribute.{Username, Realm, Nonce}
  alias Jerboa.Format.Meta
  alias Jerboa.Format.Body.Attribute
  alias Jerboa.ChannelData

  @magic MagicCookie.value

  describe "Format.encode/2" do

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

  describe "Format.decode/2" do

    test "fails given empty binary" do
      packet = <<>>

      assert {:error, %First2BitsError{bits: ^packet}} = Format.decode packet
    end

    test "fails given packet with invalid first two bits" do
      ptest first_two_val: int(min: 2, max: 3) do
        first_two = <<first_two_val::2-unit(1)>>
        packet = <<first_two::bits, 0::6-unit(1)>>

      assert {:error, %First2BitsError{bits: ^first_two}} = Format.decode packet
      end
    end

    test "fails given packet with not enough bytes for header" do
      ptest length: int(min: 2, max: 19), content: int(min: 0) do
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

    test "decodes valid ChannelData message" do
      ptest channel_number: int(min: 0x4000, max: 0x7FFF), length: int(min: 0),
        content: int(min: 0) do
        data = <<content::size(length)-unit(8)>>
        packet = <<channel_number::16, length::16, data::binary>>

        assert {:ok, channel_data} = Format.decode packet
        assert %ChannelData{channel_number: channel_number, data: data} ==
          channel_data
      end
    end

    test "decodes valid ChannelData message with extra bytes" do
      ptest channel_number: int(min: 0x4000, max: 0x7FFF), length: int(min: 0),
        content: int(min: 0), extra_length: int(min: 1) do
        data = <<content::size(length)-unit(8)>>
        extra = <<0::size(extra_length)-unit(8)>>
        packet = <<channel_number::16, length::16, data::binary, extra::binary>>

        assert {:ok, channel_data, ^extra} = Format.decode packet
        assert %ChannelData{channel_number: channel_number, data: data} ==
          channel_data
      end
    end

    test "fails to decode if ChannelData has too short data field" do
      ptest channel_number: int(min: 0x4000, max: 0x7FFF), length: int(min: 1),
        content: int(min: 0), length_offset: int(min: 1, max: ^length) do
        malformed_length = length - length_offset
        data = <<content::size(malformed_length)-unit(8)>>
        packet = <<channel_number::16, length::16, data::binary>>

        assert {:error, %ChannelDataLengthError{length: ^malformed_length}} =
          Format.decode packet
      end
    end
  end

  describe "Format.decode!/2" do
    test "raises an exception upon failure" do
      packet = <<255, "Supercalifragilisticexpialidocious!"::binary>>

      assert_raise Jerboa.Format.First2BitsError, fn -> Format.decode!(packet) end
    end

    test "returns value without an :ok tuple" do
      packet = <<0::2, 1::14, 0::16, @magic::32, 0::96>>

      assert %Params{} = Format.decode!(packet)
    end
  end

  test "MI values passed as attributes shadow values passed as options" do
    username_one = "alice"
    realm_one = "wonderland"
    username_two = "harry"
    realm_two = "hogwarts"
    secret = "secret"

    bin =
      Params.new()
      |> Params.put_class(:request)
      |> Params.put_method(:allocate)
      |> Params.put_attr(%Username{value: username_one})
      |> Params.put_attr(%Realm{value: realm_one})
      |> Format.encode(username: username_two, realm: realm_two, secret: secret)

    assert {:ok, _} = Format.decode(bin, secret: secret)
  end

  test "MI applied with encode/2 is verified byd decode/2 given same secret" do
    username = "alice"
    realm = "wonderland"
    secret = "secret"

    bin =
      Params.new()
      |> Params.put_class(:request)
      |> Params.put_method(:allocate)
      |> Params.put_attr(%Username{value: username})
      |> Params.put_attr(%Realm{value: realm})
      |> Format.encode(secret: secret)

    assert {:ok, params} = Format.decode(bin, secret: secret)
    assert params.signed?
    assert params.verified?
  end

  test "decode/2 set :verified? to false given different secret
    than encode/2" do
    username = "alice"
    realm = "wonderland"
    secret = "secret"
    other_secret = "other_secret"

    bin =
      Params.new()
      |> Params.put_class(:request)
      |> Params.put_method(:allocate)
      |> Params.put_attr(%Username{value: username})
      |> Params.put_attr(%Realm{value: realm})
      |> Format.encode(secret: secret)

    assert {:ok, params} = Format.decode(bin, secret: other_secret)
    assert params.signed?
    refute params.verified?
  end

  test "decode/2 sets :verified? to false given different username
    than encode/2" do
    username = "alice"
    other_username = "harry"
    realm = "wonderland"
    secret = "secret"

    bin =
      Params.new()
      |> Params.put_class(:request)
      |> Params.put_method(:allocate)
      |> Params.put_attr(%Realm{value: realm})
      |> Format.encode(secret: secret, username: username)

    assert {:ok, params} =
      Format.decode(bin, secret: secret, username: other_username)
    assert params.signed?
    refute params.verified?
  end

  test "decode/2 sets :verified? to false given different realm
    than encode/2" do
    username = "alice"
    realm = "wonderland"
    other_realm = "hogwarts"
    secret = "secret"

    bin =
      Params.new()
      |> Params.put_class(:request)
      |> Params.put_method(:allocate)
      |> Params.put_attr(%Username{value: username})
      |> Format.encode(secret: secret, realm: realm)

    assert {:ok, params} =
      Format.decode(bin, secret: secret, realm: other_realm)
    assert params.signed?
    refute params.verified?
  end

  test "attributes after MI are ignored" do
    secret = "secret"
    bin =
      Params.new()
      |> Params.put_class(:request)
      |> Params.put_method(:allocate)
      |> Params.put_attr(%Username{value: "alice"})
      |> Params.put_attr(%Realm{value: "wonderland"})
      |> Format.encode(secret: secret)
    {_, extra_attr} = Attribute.encode(%Meta{}, %Nonce{value: "1234"})
    <<header::20-bytes, body::binary>> = bin
    <<0::2, type::14, length::16, header_rest::binary>> = header
    new_length = length + byte_size(extra_attr)
    new_header = <<0::2, type::14, (new_length)::16, header_rest::binary>>
    modified_bin = new_header <> body <> extra_attr

    assert {:ok, params} = Format.decode(modified_bin, secret: secret)
    assert %Username{} = Params.get_attr(params, Username)
    assert %Realm{} = Params.get_attr(params, Realm)
    assert nil == Params.get_attr(params, Nonce)
  end

  test "sets :signed? and :verified? to false if there is no MI attribute" do
    bin =
      Params.new()
      |> Params.put_class(:request)
      |> Params.put_method(:allocate)
      |> Format.encode()

    assert {:ok, params} = Format.decode(bin)
    refute params.signed?
    refute params.verified?
  end
end
