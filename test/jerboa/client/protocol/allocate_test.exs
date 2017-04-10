defmodule Jerboa.Client.Protocol.AllocateTest do
  use ExUnit.Case

  alias Jerboa.Params
  alias Jerboa.Client.Protocol
  alias Jerboa.Client.Protocol.Allocate
  alias Jerboa.Test.Helper.Params, as: PH
  alias Jerboa.Test.Helper.Credentials, as: CH
  alias Jerboa.Format.Body.Attribute.XORMappedAddress, as: XMA
  alias Jerboa.Format.Body.Attribute.XORRelayedAddress, as: XRA
  alias Jerboa.Format.Body.Attribute.{Lifetime, ErrorCode, Nonce, Realm}

  test "request/1 returns valid allocate request signed with credentials" do
    creds = CH.valid_creds()

    {id, request} = Allocate.request(creds)
    params = Protocol.decode!(request, creds)

    assert params.identifier == id
    assert params.class == :request
    assert params.method == :allocate
    assert params.signed?
    assert params.verified?
    assert PH.username(params) == creds.username
    assert PH.realm(params) == creds.realm
    assert PH.nonce(params) == creds.nonce
  end

  describe "eval_response/2" do
    test "returns relayed address and lifetime on successful allocate reposnse" do
      creds = CH.valid_creds()
      address = {127, 0, 0, 1}
      port = 33_333
      lifetime = 600

      params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Lifetime{duration: lifetime})
        |> Params.put_attr(XRA.new(address, port))
        |> Params.put_attr(XMA.new(address, port))

      assert {:ok, {address, port}, lifetime} ==
        Allocate.eval_response(params, creds)
    end

    test "returns :bad_response on invalid STUN method" do
      creds = CH.valid_creds()
      address = {127, 0, 0, 1}
      port = 33_333
      lifetime = 600

      params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:binding)
        |> Params.put_attr(%Lifetime{duration: lifetime})
        |> Params.put_attr(XRA.new(address, port))
        |> Params.put_attr(XMA.new(address, port))

      assert {:error, :bad_response, creds} ==
        Allocate.eval_response(params, creds)
    end

    test "returns :bad_response without XOR-RELAYED-ADDRESS" do
      creds = CH.valid_creds()
      address = {127, 0, 0, 1}
      port = 33_333
      lifetime = 600

      params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Lifetime{duration: lifetime})
        |> Params.put_attr(XMA.new(address, port))

      assert {:error, :bad_response, creds} ==
        Allocate.eval_response(params, creds)
    end

    test "returns :bad_response without XOR-MAPPED-ADDRESS" do
      creds = CH.valid_creds()
      address = {127, 0, 0, 1}
      port = 33_333
      lifetime = 600

      params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Lifetime{duration: lifetime})
        |> Params.put_attr(XRA.new(address, port))

      assert {:error, :bad_response, creds} ==
        Allocate.eval_response(params, creds)
    end

    test "returns :bad_response without LIFETIME" do
      creds = CH.valid_creds()
      address = {127, 0, 0, 1}
      port = 33_333

      params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:allocate)
        |> Params.put_attr(XRA.new(address, port))
        |> Params.put_attr(XMA.new(address, port))

      assert {:error, :bad_response, creds} ==
        Allocate.eval_response(params, creds)
    end

    test "returns :bad_response on failure without ERROR-CODE" do
      creds = CH.valid_creds()

      params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:allocate)

      assert {:error, :bad_response, creds} ==
        Allocate.eval_response(params, creds)
    end

    test "returns creds with updated nonce on :stale_nonce error" do
      creds = CH.valid_creds() |> Map.put(:nonce, "I'm expired")
      new_nonce = CH.valid_nonce()

      params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Nonce{value: new_nonce})
        |> Params.put_attr(%ErrorCode{name: :stale_nonce})

      assert {:error, :stale_nonce, %{creds | nonce: new_nonce}} ==
        Allocate.eval_response(params, creds)
    end

    test "returns creds with filled in realm and nonce on :unauthorized "
      <> "when realm in creds is nil" do
      creds = CH.valid_creds() |> Map.put(:realm, nil)
      realm = "wonderland"
      nonce = "dcba"

      params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Nonce{value: nonce})
        |> Params.put_attr(%Realm{value: realm})
        |> Params.put_attr(%ErrorCode{name: :unauthorized})

      assert {:error, :unauthorized, %{realm: ^realm, nonce: ^nonce}} =
        Allocate.eval_response(params, creds)
    end

    test "returns unchanged creds on :unauthorized when realm in creds is not nil" do
      creds = CH.valid_creds()
      realm = "wonderland"
      nonce = "dcba"

      params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Nonce{value: nonce})
        |> Params.put_attr(%Realm{value: realm})
        |> Params.put_attr(%ErrorCode{name: :unauthorized})

      assert {:error, :unauthorized, creds} ==
        Allocate.eval_response(params, creds)
      end

    test "returns error name and unchanged creds on other errors" do
      creds = CH.valid_creds()
      error = :allocation_mismatch

      params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%ErrorCode{name: error})

      assert {:error, error, creds} == Allocate.eval_response(params, creds)
    end
  end
end
