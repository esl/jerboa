defmodule Jerboa.Client.Protocol.CreatePermissionTest do
  use ExUnit.Case

  alias Jerboa.Params
  alias Jerboa.Client.Protocol
  alias Jerboa.Client.Protocol.CreatePermission
  alias Jerboa.Test.Helper.Params, as: PH
  alias Jerboa.Test.Helper.Credentials, as: CH
  alias Jerboa.Format.Body.Attribute.XORPeerAddress, as: XPA
  alias Jerboa.Format.Body.Attribute.{Nonce, ErrorCode}

  @moduletag :now

  test "request/2 returns valid create permission request signed with creds" do
    creds = CH.valid_creds()
    peer_addr1 = {127, 0, 0, 1}
    peer_addr2 = {127, 0, 0, 2}

    {id, request} = CreatePermission.request(creds, [peer_addr1, peer_addr2])
    params = Protocol.decode!(request, creds)

    assert params.identifier == id
    assert params.class == :request
    assert params.method == :create_permission
    assert params.signed?
    assert params.verified?
    assert PH.username(params) == creds.username
    assert PH.realm(params) == creds.realm
    assert PH.nonce(params) == creds.nonce
    xor_peer_addrs = params |> Params.get_attrs(XPA) |> Enum.map(& &1.address)
    assert peer_addr1 in xor_peer_addrs
    assert peer_addr2 in xor_peer_addrs
  end

    describe "eval_response/2" do
    test "returns :ok on successful refresh response" do
      creds = CH.valid_creds()

      params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:create_permission)

      assert :ok == CreatePermission.eval_response(params, creds)
    end

    test "returns :bad_response on invalid STUN method" do
      creds = CH.valid_creds()

      params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:allocate)

      assert {:error, :bad_response, creds} ==
        CreatePermission.eval_response(params, creds)
    end

    test "returns :bad_response on failure without ERROR-CODE" do
      creds = CH.valid_creds()

      params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:create_permission)

      assert {:error, :bad_response, creds} ==
        CreatePermission.eval_response(params, creds)
    end

    test "returns creds with updated nonce on :stale_nonce error" do
      creds = CH.valid_creds() |> Map.put(:nonce, "I'm expired")
      new_nonce = CH.valid_nonce()

      params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:create_permission)
        |> Params.put_attr(%Nonce{value: new_nonce})
        |> Params.put_attr(%ErrorCode{name: :stale_nonce})

      assert {:error, :stale_nonce, %{creds | nonce: new_nonce}} ==
        CreatePermission.eval_response(params, creds)
    end

    test "returns unchanged creds and error name on other errors" do
      creds = CH.valid_creds()
      error = :forbidden

      params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:create_permission)
        |> Params.put_attr(%ErrorCode{name: error})

      assert {:error, error, creds} == CreatePermission.eval_response(params, creds)
    end
  end
end
