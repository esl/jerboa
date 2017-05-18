defmodule Jerboa.Client.Protocol.ChannelBindTest do
  use ExUnit.Case

  alias Jerboa.Params
  alias Jerboa.Client.Protocol
  alias Jerboa.Client.Protocol.ChannelBind
  alias Jerboa.Test.Helper.Params, as: PH
  alias Jerboa.Test.Helper.Credentials, as: CH
  alias Jerboa.Format.Body.Attribute.XORPeerAddress, as: XPA
  alias Jerboa.Format.Body.Attribute.{ChannelNumber, Nonce, ErrorCode}

  test "request/2 returns valid channel bind request signed with creds" do
    creds = CH.final()
    channel_number = 0x4001
    peer_ip = {127, 0, 0, 1}
    peer_port = 1234
    peer = {peer_ip, peer_port}

    {id, request} = ChannelBind.request(creds, peer, channel_number)
    params = Protocol.decode!(request, creds)

    assert params.identifier == id
    assert params.class == :request
    assert params.method == :channel_bind
    assert params.signed?
    assert params.verified?
    assert PH.username(params) == creds.username
    assert PH.realm(params) == creds.realm
    assert PH.nonce(params) == creds.nonce
    assert %ChannelNumber{number: channel_number} ==
      Params.get_attr(params, ChannelNumber)
    assert %XPA{address: ^peer_ip, port: ^peer_port, family: :ipv4} =
      Params.get_attr(params, XPA)
  end

  describe "eval_response/2" do
    test "returns :ok on successful channel bind response" do
      creds = CH.final()

      params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:channel_bind)

      assert :ok == ChannelBind.eval_response(params, creds)
    end

    test "returns :bad_response on invalid STUN method" do
      creds = CH.final()

      params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_class(:allocate)

      assert {:error, :bad_response, creds} ==
        ChannelBind.eval_response(params, creds)
    end

    test "returns :bad_response on failure without ERROR-CODE" do
      creds = CH.final()

      params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:channel_bind)

      assert {:error, :bad_response, creds} ==
        ChannelBind.eval_response(params, creds)
    end

    test "returns creds with updated nonce on :stale_nonce error" do
      creds = CH.final() |> Map.put(:nonce, "I'm expired")
      new_nonce = CH.valid_nonce()

      params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:channel_bind)
        |> Params.put_attr(%Nonce{value: new_nonce})
        |> Params.put_attr(%ErrorCode{name: :stale_nonce})

      assert {:error, :stale_nonce, %{creds | nonce: new_nonce}} ==
        ChannelBind.eval_response(params, creds)
    end

    test "returns unchanged creds and error name on other errors" do
      creds = CH.final()
      error = :forbidden

      params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:channel_bind)
        |> Params.put_attr(%ErrorCode{name: error})

      assert {:error, error, creds} == ChannelBind.eval_response(params, creds)
    end
  end
end
