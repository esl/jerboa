defmodule Jerboa.Format.Body.Attribute.RealmTest do
  use ExUnit.Case
  use Quixir

  alias Jerboa.Format.Body.Attribute.Realm
  alias Jerboa.Format.Realm.LengthError
  alias Jerboa.Format.Meta

  describe "decode/1" do
    test "REALM attribtue of valid length" do
      ptest value: string(max: Realm.max_chars) do
        assert {:ok, _, %Realm{value: ^value}} = Realm.decode(value, %Meta{})
      end
    end

    test "REALM attribute of invalid length" do
      length = Realm.max_chars + 1
      value = String.duplicate("a", length)

      assert {:error, %LengthError{length: ^length}} = Realm.decode(value, %Meta{})
    end
  end

  describe "encode/1" do
    test "REALM attribute with string value of valid length" do
      ptest value: string(max: Realm.max_chars) do
        assert value == %Realm{value: value} |> Realm.encode()
      end
    end

    test "REALM attribute with string value of invalid length" do
      value = String.duplicate("a", Realm.max_chars + 1)

      assert_raise ArgumentError, fn ->
        %Realm{value: value} |> Realm.encode()
      end
    end

    test "REALM attribute with non-string value" do
      assert_raise ArgumentError, fn ->
        %Realm{value: 123} |> Realm.encode()
      end
    end
  end

end
