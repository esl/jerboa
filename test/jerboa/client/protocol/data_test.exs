defmodule Jerboa.Client.Protocol.DataTest do
  use ExUnit.Case

  alias Jerboa.Params
  alias Jerboa.Client.Protocol.Data
  alias Jerboa.Format.Body.Attribute.Data, as: DataAttr
  alias Jerboa.Format.Body.Attribute.XORPeerAddress, as: XPA

  describe "eval_indication/1" do
    test "returns peer address and data given valid data indication" do
      data = "alicehasacat"
      peer_addr = {127, 0, 0, 1}
      peer_port = 33_333
      params =
        Params.new()
        |> Params.put_class(:indication)
        |> Params.put_method(:data)
        |> Params.put_attr(%DataAttr{content: data})
        |> Params.put_attr(XPA.new(peer_addr, peer_port))

      assert {:ok, {peer_addr, peer_port}, data} == Data.eval_indication(params)
    end

    test "returns :error on invalid STUN class" do
      data = "alicehasacat"
      peer_addr = {127, 0, 0, 1}
      peer_port = 33_333
      params =
        Params.new()
        |> Params.put_class(:request)
        |> Params.put_method(:data)
        |> Params.put_attr(%DataAttr{content: data})
        |> Params.put_attr(XPA.new(peer_addr, peer_port))

      assert :error == Data.eval_indication(params)
    end

    test "returns :error on invalid STUN method" do
      data = "alicehasacat"
      peer_addr = {127, 0, 0, 1}
      peer_port = 33_333
      params =
        Params.new()
        |> Params.put_class(:indication)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%DataAttr{content: data})
        |> Params.put_attr(XPA.new(peer_addr, peer_port))

      assert :error == Data.eval_indication(params)
    end

    test "returns :error without DATA attribute" do
      peer_addr = {127, 0, 0, 1}
      peer_port = 33_333
      params =
        Params.new()
        |> Params.put_class(:indication)
        |> Params.put_method(:data)
        |> Params.put_attr(XPA.new(peer_addr, peer_port))

      assert :error == Data.eval_indication(params)
    end

    test "returns :error without XOR-PEER-ADDRESS attribute" do
      data = "alicehasacat"
      params =
        Params.new()
        |> Params.put_class(:indication)
        |> Params.put_method(:data)
        |> Params.put_attr(%DataAttr{content: data})

      assert :error == Data.eval_indication(params)
    end
  end
end
