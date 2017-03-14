defmodule Jerboa.FormatTest do
  use ExUnit.Case, async: true
  use Quixir

  alias Jerboa.Test.Helper.XORMappedAddress, as: XORMAHelper

  alias Jerboa.{Format, Params}
  alias Format.{HeaderLengthError, BodyLengthError}
  alias Jerboa.Format.Header.MagicCookie
  alias Jerboa.Format.Body.Attribute.{Username, Realm, Nonce}
  alias Jerboa.Format.MessageIntegrity.VerificationError
  alias Jerboa.Format.Meta
  alias Jerboa.Format.Body.Attribute

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

  describe "Format.decode!/2" do
    test "raises an exception upon failure" do
      packet = "Supercalifragilisticexpialidocious!"

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

  test "encode/2 and decode/2 apply and verify MI symmetrically" do
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

    assert {:ok, _} = Format.decode(bin, secret: secret)
  end

  test "decode/2 fails given different secret than encode/2" do
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

    assert {:error, %VerificationError{}} =
      Format.decode(bin, secret: other_secret)
  end

  test "decode/2 fails given different username than encode/2" do
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

    assert {:error, %VerificationError{}} =
      Format.decode(bin, secret: secret, username: other_username)
  end

  test "decode/2 fails given different realm than encode/2" do
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

    assert {:error, %VerificationError{}} =
      Format.decode(bin, secret: secret, realm: other_realm)
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
end
