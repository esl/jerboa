defmodule Jerboa.Client.Protocol.AllocateTest do
  use ExUnit.Case

  alias Jerboa.Params
  alias Jerboa.Client.Credentials
  alias Jerboa.Client.Protocol
  alias Jerboa.Client.Protocol.Allocate
  alias Jerboa.Test.Helper.Params, as: PH
  alias Jerboa.Test.Helper.Credentials, as: CH
  alias Jerboa.Format.Body.Attribute.XORMappedAddress, as: XMA
  alias Jerboa.Format.Body.Attribute.XORRelayedAddress, as: XRA
  alias Jerboa.Format.Body.Attribute.{Lifetime, ErrorCode, Nonce, Realm,
                                      EvenPort, ReservationToken}

  describe "request/2" do
    test "returns valid allocate request signed with credentials" do
      creds = CH.final()

      {id, request} = Allocate.request(creds, [])
      params = Protocol.decode!(request, creds)

      assert params.identifier == id
      assert params.class == :request
      assert params.method == :allocate
      assert params.signed?
      assert params.verified?
      assert nil == Params.get_attr(params, EvenPort)
      assert PH.username(params) == creds.username
      assert PH.realm(params) == creds.realm
      assert PH.nonce(params) == creds.nonce
    end

    test "returns valid allocate request with EVEN-PORT attribute" do
      creds = CH.final()

      {id, request} = Allocate.request(creds, even_port: true)
      params = Protocol.decode!(request, creds)

      assert params.identifier == id
      assert params.class == :request
      assert params.method == :allocate
      assert params.signed?
      assert params.verified?
      assert %EvenPort{reserved?: false} == Params.get_attr(params, EvenPort)
      assert PH.username(params) == creds.username
      assert PH.realm(params) == creds.realm
      assert PH.nonce(params) == creds.nonce
    end

    test "returns valid allocate request with reserved EVEN-PORT attribute" do
      creds = CH.final()

      {id, request} = Allocate.request(creds, reserve: true)
      params = Protocol.decode!(request, creds)

      assert params.identifier == id
      assert params.class == :request
      assert params.method == :allocate
      assert params.signed?
      assert params.verified?
      assert %EvenPort{reserved?: true} == Params.get_attr(params, EvenPort)
      assert PH.username(params) == creds.username
      assert PH.realm(params) == creds.realm
      assert PH.nonce(params) == creds.nonce
    end

    test "returns valid allocate request with RESERVATION-TOKEN attribute" do
      creds = CH.final()
      token = <<0::8*8>> # token must be 8 bytes long

      {id, request} = Allocate.request(creds, reservation_token: token)
      params = Protocol.decode!(request, creds)

      assert params.identifier == id
      assert params.class == :request
      assert params.method == :allocate
      assert params.signed?
      assert params.verified?
      assert %ReservationToken{value: token} ==
        Params.get_attr(params, ReservationToken)
      assert PH.username(params) == creds.username
      assert PH.realm(params) == creds.realm
      assert PH.nonce(params) == creds.nonce
    end
  end

  describe "eval_response/2" do
    test "returns relayed address and lifetime on successful allocate response" do
      creds = CH.final()
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
        Allocate.eval_response(params, creds, [])
    end

    test "returns :bad_response on invalid STUN method" do
      creds = CH.final()
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
        Allocate.eval_response(params, creds, [])
    end

    test "returns :bad_response without XOR-RELAYED-ADDRESS" do
      creds = CH.final()
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
        Allocate.eval_response(params, creds, [])
    end

    test "returns :bad_response without XOR-MAPPED-ADDRESS" do
      creds = CH.final()
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
        Allocate.eval_response(params, creds, [])
    end

    test "returns :bad_response without LIFETIME" do
      creds = CH.final()
      address = {127, 0, 0, 1}
      port = 33_333

      params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:allocate)
        |> Params.put_attr(XRA.new(address, port))
        |> Params.put_attr(XMA.new(address, port))

      assert {:error, :bad_response, creds} ==
        Allocate.eval_response(params, creds, [])
    end

    test "returns :bad_response on failure without ERROR-CODE" do
      creds = CH.final()

      params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:allocate)

      assert {:error, :bad_response, creds} ==
        Allocate.eval_response(params, creds, [])
    end

    test "returns creds with updated nonce on :stale_nonce error" do
      creds = CH.final() |> Map.put(:nonce, "I'm expired")
      new_nonce = CH.final()

      params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Nonce{value: new_nonce})
        |> Params.put_attr(%ErrorCode{name: :stale_nonce})

      assert {:error, :stale_nonce, %{creds | nonce: new_nonce}} ==
        Allocate.eval_response(params, creds, [])
    end

    test "returns complete creds on :unauthorized" do
      creds = CH.initial()
      realm = "wonderland"
      nonce = "dcba"

      params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Nonce{value: nonce})
        |> Params.put_attr(%Realm{value: realm})
        |> Params.put_attr(%ErrorCode{name: :unauthorized})

      assert {:error, :unauthorized, creds} =
        Allocate.eval_response(params, creds, [])
      assert Credentials.complete?(creds)
      assert %{realm: ^realm, nonce: ^nonce} = creds
    end

    test "returns unchanged creds on :unauthorized when realm in creds is not nil" do
      creds = CH.final()
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
        Allocate.eval_response(params, creds, [])
      end

    test "returns error name and unchanged creds on other errors" do
      creds = CH.final()
      error = :allocation_mismatch

      params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%ErrorCode{name: error})

      assert {:error, error, creds} == Allocate.eval_response(params, creds, [])
    end

    test "returns :bad_response on response without reservation token" do
      creds = CH.final()
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

      assert {:error, :bad_response, creds} ==
        Allocate.eval_response(params, creds, [reserve: true])
    end

    test "returns reservation token if it was requested" do
      creds = CH.final()
      address = {127, 0, 0, 1}
      port = 33_333
      lifetime = 600
      token = "12345678"

      params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Lifetime{duration: lifetime})
        |> Params.put_attr(XRA.new(address, port))
        |> Params.put_attr(XMA.new(address, port))
        |> Params.put_attr(%ReservationToken{value: token})

      assert {:ok, {address, port}, lifetime, token} ==
        Allocate.eval_response(params, creds, [reserve: true])
    end

    test "doesn't return reservation token if it wasn't request" do
      creds = CH.final()
      address = {127, 0, 0, 1}
      port = 33_333
      lifetime = 600
      token = "12345678"

      params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Lifetime{duration: lifetime})
        |> Params.put_attr(XRA.new(address, port))
        |> Params.put_attr(XMA.new(address, port))
        |> Params.put_attr(%ReservationToken{value: token})

      assert {:ok, {address, port}, lifetime} ==
        Allocate.eval_response(params, creds, [])
    end
  end
end
