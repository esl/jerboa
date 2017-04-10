defmodule Jerboa.Client.Protocol.RefreshTest do
  use ExUnit.Case

  alias Jerboa.Params
  alias Jerboa.Client.Protocol
  alias Jerboa.Client.Protocol.Refresh
  alias Jerboa.Test.Helper.Params, as: PH
  alias Jerboa.Test.Helper.Credentials, as: CH
  alias Jerboa.Format.Body.Attribute.{Lifetime, Nonce, ErrorCode}

  test "request/1 returns valid refresh request signed with credentials" do
    creds = CH.valid_creds()

    {id, request} = Refresh.request(creds)
    params = Protocol.decode!(request, creds)

    assert params.identifier == id
    assert params.class == :request
    assert params.method == :refresh
    assert params.signed?
    assert params.verified?
    assert PH.username(params) == creds.username
    assert PH.realm(params) == creds.realm
    assert PH.nonce(params) == creds.nonce
  end

  describe "eval_response/2" do
    test "returns new lifetime on successful refresh response" do
      creds = CH.valid_creds()
      lifetime = 600

      params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:refresh)
        |> Params.put_attr(%Lifetime{duration: lifetime})

      assert {:ok, lifetime} == Refresh.eval_response(params, creds)
    end

    test "returns :bad_response on invalid STUN method" do
      creds = CH.valid_creds()
      lifetime = 600

      params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Lifetime{duration: lifetime})

      assert {:error, :bad_response, creds} ==
        Refresh.eval_response(params, creds)
    end

    test "returns :bad_response without LIFETIME" do
      creds = CH.valid_creds()

      params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:allocate)

      assert {:error, :bad_response, creds} ==
        Refresh.eval_response(params, creds)
    end

    test "returns :bad_response on failure without ERROR-CODE" do
      creds = CH.valid_creds()

      params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:refresh)

      assert {:error, :bad_response, creds} ==
        Refresh.eval_response(params, creds)
    end

    test "returns creds with updated nonce on :stale_nonce error" do
      creds = CH.valid_creds() |> Map.put(:nonce, "I'm expired")
      new_nonce = CH.valid_nonce()

      params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:refresh)
        |> Params.put_attr(%Nonce{value: new_nonce})
        |> Params.put_attr(%ErrorCode{name: :stale_nonce})

      assert {:error, :stale_nonce, %{creds | nonce: new_nonce}} ==
        Refresh.eval_response(params, creds)
    end

    test "returns unchanged creds and error name on other errors" do
      creds = CH.valid_creds()
      error = :allocation_quota_reached

      params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:refresh)
        |> Params.put_attr(%ErrorCode{name: error})

      assert {:error, error, creds} == Refresh.eval_response(params, creds)
    end
  end
end
