defmodule Jerboa.Client.ProtocolTest do
  use ExUnit.Case

  alias Jerboa.Client.Protocol
  alias Jerboa.Client.Protocol.Transaction
  alias Jerboa.Client.Worker
  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.XORMappedAddress

  test "bind_req/1 retuns encoded binding request" do
    %{transaction: %{req: msg}} = Protocol.bind_req(%Worker{})

    params= msg |> Format.decode!()

    assert Params.get_class(params) == :request
    assert Params.get_method(params) == :binding
    assert Params.get_attrs(params) == []
  end

  test "bind_ind/1 returns encoded binding indication" do
    %{transaction: %{req: msg}} = Protocol.bind_ind(%Worker{})

    params = msg |> Format.decode!()

    assert Params.get_class(params) == :indication
    assert Params.get_method(params) == :binding
    assert Params.get_attrs(params) == []
  end

  describe "eval_bind_resp/2" do

    ## TODO: refactor params creation to helper function
    ## and assertion on empty transaction

    test "returns mapped address given worker state with valid response" do
      address = {0, 0, 0, 0}
      port = 0
      mapped_address = %XORMappedAddress{address: address, port: port,
                                         family: :ipv4}
      resp_params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:binding)
        |> Params.put_attr(mapped_address)
      t_id = resp_params.identifier
      resp = Format.encode(resp_params)
      state = %Worker{transaction: %Transaction{id: t_id, resp: resp}}

      assert {{:ok, {^address, ^port}}, new_state} =
        Protocol.eval_bind_resp(state)
      assert new_state.transaction == %Transaction{}
    end

    test "returns error on error response" do
      address = {0, 0, 0, 0}
      port = 0
      mapped_address = %XORMappedAddress{address: address, port: port,
                                         family: :ipv4}
      resp_params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:binding)
        |> Params.put_attr(mapped_address)
      t_id = resp_params.identifier
      resp = Format.encode(resp_params)
      state = %Worker{transaction: %Transaction{id: t_id, resp: resp}}

      assert {{:error, _}, _} = Protocol.eval_bind_resp(state)
    end

    test "returns error on invalid transaction id" do
      address = {0, 0, 0, 0}
      port = 0
      mapped_address = %XORMappedAddress{address: address, port: port,
                                         family: :ipv4}
      resp_params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:binding)
        |> Params.put_attr(mapped_address)
      t_id = Params.generate_id()
      resp = Format.encode(resp_params)
      state = %Worker{transaction: %Transaction{id: t_id, resp: resp}}

      assert {{:error, _}, _} = Protocol.eval_bind_resp(state)
    end

    test "returns error on invalid STUN method" do
      address = {0, 0, 0, 0}
      port = 0
      mapped_address = %XORMappedAddress{address: address, port: port,
                                         family: :ipv4}
      resp_params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:allocate)
        |> Params.put_attr(mapped_address)
      t_id = resp_params.identifier
      resp = Format.encode(resp_params)
      state = %Worker{transaction: %Transaction{id: t_id, resp: resp}}

      assert {{:error, _}, _} = Protocol.eval_bind_resp(state)
    end

    test "returns error on message without XOR-MAPPED-ADDRESS" do
      resp_params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:allocate)
      t_id = resp_params.identifier
      resp = Format.encode(resp_params)
      state = %Worker{transaction: %Transaction{id: t_id, resp: resp}}

      assert {{:error, _}, _} = Protocol.eval_bind_resp(state)
    end
  end
end
