defmodule Jerboa.Client.ProtocolTest do
  use ExUnit.Case

  alias Jerboa.Client.Protocol
  alias Jerboa.Client.Protocol.Transaction
  alias Jerboa.Client.Worker
  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.{XORMappedAddress, RequestedTransport,
                                      Username, Realm, Nonce, XORRelayedAddress,
                                      Lifetime, ErrorCode}

  test "bind_req/1 retuns encoded binding request" do
    %{transaction: %{req: msg}} = Protocol.bind_req(%Worker{})

    params = msg |> Format.decode!()

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

  describe "allocate_req/1" do
    test "returns unsigned message if credentials are not known yet" do
      state = %Worker{}

      %{transaction: %{req: msg}} = state |> Protocol.allocate_req()
      params = Format.decode!(msg)

      assert :request == Params.get_class(params)
      assert :allocate == Params.get_method(params)
      assert %RequestedTransport{protocol: :udp} ==
        Params.get_attr(params, RequestedTransport)
    end

    test "returns signed message if credentials are known" do
      username = "alice"
      realm = "wonderland"
      secret = "1234"
      nonce = "abcd"
      state = %Worker{username: username, realm: realm, secret: secret, nonce: nonce}

      %{transaction: %{req: msg}} = state |> Protocol.allocate_req()
      params = Format.decode!(msg, secret: secret)

      assert :request == Params.get_class(params)
      assert :allocate == Params.get_method(params)
      assert %RequestedTransport{protocol: :udp} ==
        Params.get_attr(params, RequestedTransport)
      assert %Username{value: username} == Params.get_attr(params, Username)
      assert %Realm{value: realm} == Params.get_attr(params, Realm)
      assert %Nonce{value: nonce} == Params.get_attr(params, Nonce)
    end
  end

  describe "eval_allocate_resp/1" do
    test "returns error on response with wrong method" do
      username = "alice"
      realm = "wonderland"
      secret = "1234"
      nonce = "abcd"
      resp_params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:binding)
        |> Params.put_attr(%Realm{value: realm})
        |> Params.put_attr(%Nonce{value: nonce})
      t_id = resp_params.identifier

      resp = Format.encode(resp_params, secret: secret, username: username)
      state = %Worker{transaction: %Transaction{id: t_id, resp: resp}, username: username,
                      realm: realm, secret: secret}

      assert {{:error, :bad_response}, _} = Protocol.eval_allocate_resp(state)
    end

    test "returns error on response with invalid transaction id" do
      username = "alice"
      realm = "wonderland"
      secret = "1234"
      nonce = "abcd"
      resp_params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Realm{value: realm})
        |> Params.put_attr(%Nonce{value: nonce})
      t_id = Params.generate_id()

      resp = Format.encode(resp_params)
      state = %Worker{transaction: %Transaction{id: t_id, resp: resp}, username: username,
                      realm: realm, secret: secret}

      assert {{:error, :bad_response}, _} = Protocol.eval_allocate_resp(state)
    end

    test "returns error on response without XOR-RELAYED-ADDRESS" do
      address = {0, 0, 0, 0}
      port = 0
      duration = 600
      mapped_address = %XORMappedAddress{address: address, port: port,
                                         family: :ipv4}
      lifetime = %Lifetime{duration: duration}
      username = "alice"
      realm = "wonderland"
      secret = "1234"
      nonce = "abcd"
      resp_params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Realm{value: realm})
        |> Params.put_attr(%Nonce{value: nonce})
        |> Params.put_attr(mapped_address)
        |> Params.put_attr(lifetime)
      t_id = resp_params.identifier

      resp = Format.encode(resp_params, secret: secret, username: username)
      state = %Worker{transaction: %Transaction{id: t_id, resp: resp}, username: username,
                      realm: realm, secret: secret}

      assert {{:error, :bad_response}, _} = Protocol.eval_allocate_resp(state)
    end

    test "returns error on response without XOR-MAPPED-ADDRESS" do
      address = {0, 0, 0, 0}
      port = 0
      duration = 600
      relayed_address = %XORRelayedAddress{address: address, port: port,
                                           family: :ipv4}
      lifetime = %Lifetime{duration: duration}
      username = "alice"
      realm = "wonderland"
      secret = "1234"
      nonce = "abcd"
      resp_params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Realm{value: realm})
        |> Params.put_attr(%Nonce{value: nonce})
        |> Params.put_attr(relayed_address)
        |> Params.put_attr(lifetime)
      t_id = resp_params.identifier

      resp = Format.encode(resp_params, secret: secret, username: username)
      state = %Worker{transaction: %Transaction{id: t_id, resp: resp}, username: username,
                      realm: realm, secret: secret}

      assert {{:error, :bad_response}, _} = Protocol.eval_allocate_resp(state)
    end

    test "returns error on response without LIFETIME" do
      address = {0, 0, 0, 0}
      port = 0
      mapped_address = %XORMappedAddress{address: address, port: port,
                                         family: :ipv4}
      relayed_address = %XORRelayedAddress{address: address, port: port,
                                           family: :ipv4}
      username = "alice"
      realm = "wonderland"
      secret = "1234"
      nonce = "abcd"
      resp_params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Realm{value: realm})
        |> Params.put_attr(%Nonce{value: nonce})
        |> Params.put_attr(relayed_address)
        |> Params.put_attr(mapped_address)
      t_id = resp_params.identifier

      resp = Format.encode(resp_params, secret: secret, username: username)
      state = %Worker{transaction: %Transaction{id: t_id, resp: resp}, username: username,
                      realm: realm, secret: secret}

      assert {{:error, :bad_response}, _} = Protocol.eval_allocate_resp(state)
    end

    test "returns error on IPv6 XOR-RELAYED-ADDRESS" do
      ipv4_address = {0, 0, 0, 0}
      ipv6_address = {0, 0, 0, 0, 0, 0, 0, 0}
      port = 0
      duration = 600
      mapped_address = %XORMappedAddress{address: ipv4_address, port: port,
                                         family: :ipv4}
      relayed_address = %XORRelayedAddress{address: ipv6_address, port: port,
                                           family: :ipv6}
      lifetime = %Lifetime{duration: duration}
      username = "alice"
      realm = "wonderland"
      secret = "1234"
      nonce = "abcd"
      resp_params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Realm{value: realm})
        |> Params.put_attr(%Nonce{value: nonce})
        |> Params.put_attr(mapped_address)
        |> Params.put_attr(relayed_address)
        |> Params.put_attr(lifetime)
      t_id = resp_params.identifier

      resp = Format.encode(resp_params, secret: secret, username: username)
      state = %Worker{transaction: %Transaction{id: t_id, resp: resp}, username: username,
                      realm: realm, secret: secret}

      assert {{:error, :bad_response}, _} = Protocol.eval_allocate_resp(state)
    end

    test "returns error on IPv6 XOR-MAPPED-ADDRESS" do
      ipv4_address = {0, 0, 0, 0}
      ipv6_address = {0, 0, 0, 0, 0, 0, 0, 0}
      port = 0
      duration = 600
      mapped_address = %XORMappedAddress{address: ipv6_address, port: port,
                                         family: :ipv6}
      relayed_address = %XORRelayedAddress{address: ipv4_address, port: port,
                                           family: :ipv4}
      lifetime = %Lifetime{duration: duration}
      username = "alice"
      realm = "wonderland"
      secret = "1234"
      nonce = "abcd"
      resp_params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Realm{value: realm})
        |> Params.put_attr(%Nonce{value: nonce})
        |> Params.put_attr(mapped_address)
        |> Params.put_attr(relayed_address)
        |> Params.put_attr(lifetime)
      t_id = resp_params.identifier

      resp = Format.encode(resp_params, secret: secret, username: username)
      state = %Worker{transaction: %Transaction{id: t_id, resp: resp}, username: username,
                      realm: realm, secret: secret}

      assert {{:error, :bad_response}, _} = Protocol.eval_allocate_resp(state)
    end

    test "returns :retry and updates nonce if error response is :stale_nonce" do
      realm = "wonderland"
      old_nonce = "dcba"
      new_nonce = "abcd"
      resp_params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Realm{value: realm})
        |> Params.put_attr(%Nonce{value: new_nonce})
        |> Params.put_attr(%ErrorCode{name: :stale_nonce})
      t_id = resp_params.identifier

      resp = Format.encode(resp_params)
      state = %Worker{transaction: %Transaction{id: t_id, resp: resp}, nonce: old_nonce}

      assert {:retry, new_state} = Protocol.eval_allocate_resp(state)
      assert new_state.nonce == new_nonce
    end

    test "returns :retry and updates realm and nonce if error response is :unauthorized" do
      realm = "wonderland"
      nonce = "abcd"
      resp_params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Realm{value: realm})
        |> Params.put_attr(%Nonce{value: nonce})
        |> Params.put_attr(%ErrorCode{name: :unauthorized})
      t_id = resp_params.identifier

      resp = Format.encode(resp_params)
      state = %Worker{transaction: %Transaction{id: t_id, resp: resp}}

      assert {:retry, new_state} = Protocol.eval_allocate_resp(state)
      assert new_state.nonce == nonce
      assert new_state.realm == realm
    end

    test "returns error if error response doesn't have error code attribute" do
      realm = "wonderland"
      nonce = "abcd"
      resp_params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Realm{value: realm})
        |> Params.put_attr(%Nonce{value: nonce})
      t_id = resp_params.identifier

      resp = Format.encode(resp_params)
      state = %Worker{transaction: %Transaction{id: t_id, resp: resp}}

      assert {{:error, :bad_response}, _} = Protocol.eval_allocate_resp(state)
    end

    test "returns relayed address on valid allocate response" do
      address = {0, 0, 0, 0}
      port = 0
      duration = 600
      mapped_address = %XORMappedAddress{address: address, port: port,
                                         family: :ipv4}
      relayed_address = %XORRelayedAddress{address: address, port: port,
                                           family: :ipv4}
      lifetime = %Lifetime{duration: duration}
      username = "alice"
      realm = "wonderland"
      secret = "1234"
      nonce = "abcd"
      resp_params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:allocate)
        |> Params.put_attr(%Realm{value: realm})
        |> Params.put_attr(%Nonce{value: nonce})
        |> Params.put_attr(mapped_address)
        |> Params.put_attr(relayed_address)
        |> Params.put_attr(lifetime)
      t_id = resp_params.identifier

      resp = Format.encode(resp_params, secret: secret, username: username)
      state = %Worker{transaction: %Transaction{id: t_id, resp: resp}, username: username,
                      realm: realm, secret: secret}

      assert {{:ok, {^address, ^port}}, new_state} = Protocol.eval_allocate_resp(state)
      assert new_state.mapped_address == {address, port}
      assert new_state.relayed_address == {address, port}
      assert new_state.lifetime == duration
    end
  end
end
