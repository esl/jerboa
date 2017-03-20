defmodule Jerboa.Format.MessageIntegrityTest do
  use ExUnit.Case
  use Quixir

  alias Jerboa.Params
  alias Jerboa.Format.Header
  alias Jerboa.Format.Body
  alias Jerboa.Format.MessageIntegrity
  alias Jerboa.Format.Meta
  alias Jerboa.Format.Body.Attribute.{Nonce, Realm, Username}
  alias Jerboa.Format.MessageIntegrity.RealmMissingError
  alias Jerboa.Format.MessageIntegrity.UsernameMissingError
  alias Jerboa.Format.MessageIntegrity.SecretMissingError
  alias Jerboa.Format.MessageIntegrity.VerificationError

  @mi_attr_length 24

  describe "apply/1" do
    test "does not apply MI when secret is not given" do
      options = [username: "alice", realm: "wonderland"]
      body_without_mi = <<>>

      meta = %Meta{options: options} |> MessageIntegrity.apply()

      assert meta.body == body_without_mi
    end

    test "does not apply MI when username is not given" do
      options = [secret: "secret", realm: "wonderland"]
      meta = %Meta{options: options}

      assert meta == MessageIntegrity.apply(meta)
    end

    test "does not apply MI when realm is not given" do
      options = [username: "alice", secret: "secret"]
      meta = %Meta{options: options}

      assert meta == MessageIntegrity.apply(meta)
    end

    test "applies MI when necessary values are passed as options" do
      params =
        Params.new()
        |> Params.put_class(:request)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Nonce{value: "1234"})
      options = [username: "alice", realm: "wonderland", secret: "secret"]
      meta =
        %Meta{params: params, options: options}
        |> Body.encode()
        |> Header.encode()

      new_meta = MessageIntegrity.apply(meta)

      assert byte_size(meta.body) + @mi_attr_length == byte_size(new_meta.body)
    end

    test "applies MI when username as realm are passed as attributes" do
      params =
        Params.new()
        |> Params.put_class(:request)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Nonce{value: "1234"})
        |> Params.put_attr(%Username{value: "alice"})
        |> Params.put_attr(%Realm{value: "wonderland"})
      options = [secret: "secret"]
      meta =
        %Meta{params: params, options: options}
        |> Body.encode()
        |> Header.encode()

      new_meta = MessageIntegrity.apply(meta)

      assert byte_size(meta.body) + @mi_attr_length == byte_size(new_meta.body)
    end
  end

  describe "verify/1" do
    test "changes nothing when MI is empty" do
      empty_mi = <<>>
      meta = %Meta{message_integrity: empty_mi}

      assert {:ok, meta} == MessageIntegrity.verify(meta)
    end

    test "fails when secret is not given" do
      options = [username: "alice", realm: "wonderland"]
      meta = %Meta{options: options, message_integrity: "abcd"}

      assert {:error, %SecretMissingError{}} = MessageIntegrity.verify(meta)
    end

    test "fails when username is not given" do
      options = [secret: "secret", realm: "wonderland"]
      meta = %Meta{options: options, message_integrity: "abcd"}

      assert {:error, %UsernameMissingError{}} = MessageIntegrity.verify(meta)
    end

    test "fails when realm is not given" do
      options = [secret: "secret", username: "alice"]
      meta = %Meta{options: options, message_integrity: "abcd"}

      assert {:error, %RealmMissingError{}} = MessageIntegrity.verify(meta)
    end

    test "fails if extracted MI is not valid (values passed as options)" do
      params =
        Params.new()
        |> Params.put_class(:request)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Nonce{value: "1234"})
      options = [username: "alice", realm: "wonderland", secret: "secret"]
      meta =
        %Meta{params: params, options: options, message_integrity: "abcd"}
        |> Body.encode()
        |> Header.encode()

      assert {:error, %VerificationError{}} = MessageIntegrity.verify(meta)
    end

    test "fails if extracted MI is not valid (values passed as attibutes)" do
      params =
        Params.new()
        |> Params.put_class(:request)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Nonce{value: "1234"})
        |> Params.put_attr(%Username{value: "alice"})
        |> Params.put_attr(%Realm{value: "wonderland"})
      options = [secret: "secret"]
      meta =
        %Meta{params: params, options: options, message_integrity: "abcd"}
        |> Body.encode()
        |> Header.encode()

      assert {:error, %VerificationError{}} = MessageIntegrity.verify(meta)
    end
  end
end
