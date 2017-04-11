defmodule Jerboa.Client.ProtocolTest do
  use ExUnit.Case

  alias Jerboa.{Params, Format}
  alias Jerboa.Client.Protocol
  alias Jerboa.Format.Body.Attribute.{Nonce, ErrorCode}
  alias Jerboa.Test.Helper.Params, as: PH
  alias Jerboa.Test.Helper.Credentials, as: CH

  describe "encode_request/2" do
    test "signs params if given credentials are complete" do
      creds = CH.final()
      params =
        Params.new()
        |> Params.put_class(:request)
        |> Params.put_method(:allocate)

      {id, request} = Protocol.encode_request(params, creds)
      decoded = Format.decode!(request, secret: creds.secret,
        username: creds.username, realm: creds.realm)

      assert id == params.identifier
      assert decoded.signed?
      assert decoded.verified?
    end

    test "does not sign params if credentials are not complete" do
      creds = CH.initial()
      params =
        Params.new()
        |> Params.put_class(:request)
        |> Params.put_method(:allocate)

      {id, request} = Protocol.encode_request(params, creds)
      decoded = Format.decode!(request)

      assert id == params.identifier
      refute decoded.signed?
      refute decoded.verified?
    end
  end

  describe "base_params/1" do
    test "returns params with credentials if credentials are complete" do
      creds = CH.final()

      params = Protocol.base_params(creds)

      assert PH.username(params) == creds.username
      assert PH.realm(params) == creds.realm
      assert PH.nonce(params) == creds.nonce
    end

    test "returns params without credentials if credentials are not complete" do
      creds = CH.initial()

      params = Protocol.base_params(creds)

      refute PH.username(params)
      refute PH.realm(params)
      refute PH.nonce(params)
    end
  end

  describe "eval_failure/2" do
    test "returns :bad_response given params without error code" do
      creds = CH.final()
      params = Params.new() |> Params.put_class(:failure)

      assert {:error, :bad_response, creds} ==
        Protocol.eval_failure(params, creds)
    end

    test "returns credentials with updated nonce if error reason is :stale_nonce" do
      new_nonce = "abcd"
      old_nonce = CH.invalid_nonce()
      creds = CH.final() |> Map.put(:nonce, old_nonce)
      params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_attr(%ErrorCode{name: :stale_nonce})
        |> Params.put_attr(%Nonce{value: new_nonce})

      result = Protocol.eval_failure(params, creds)

      assert {:error, :stale_nonce, new_creds} = result
      assert %{creds | nonce: new_nonce} == new_creds
    end

    test "returns :bad_response on :stale_nonce error without nonce attribute" do
      creds = CH.final()

      params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_attr(%ErrorCode{name: :stale_nonce})

      assert {:error, :bad_response, creds} ==
        Protocol.eval_failure(params, creds)
    end

    test "returns error name of error included in params" do
      creds = CH.final()
      error = :allocation_mismatch

      params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_attr(%ErrorCode{name: error})

      assert {:error, error, creds} ==
        Protocol.eval_failure(params, creds)
    end
  end
end
