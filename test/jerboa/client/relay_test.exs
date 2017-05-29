defmodule Jerboa.Client.RelayTest do
  use ExUnit.Case

  @moduletag :now

  alias Jerboa.Client.Relay
  alias Jerboa.Client.Relay.Channel

  describe "active?/1" do
    test "returns true if relayed address is not nil" do
      relay = %Relay{address: {{127, 0, 0, 1}, 12_345}}

      assert Relay.active?(relay)
    end

    test "returns false if relayed address is nil" do
      relay = %Relay{address: nil}

      refute Relay.active?(relay)
    end
  end

  test "put_address/2 sets relay address" do
    address = {{127, 0, 0, 1}, 12_345}

    relay = %Relay{} |> Relay.put_address(address)

    assert relay.address == address
  end

  test "put_lifetime/2 sets relay lifetime" do
    lifetime = 600

    relay = %Relay{} |> Relay.put_lifetime(lifetime)

    assert relay.lifetime == lifetime
  end

  test "put_timer_ref/2 sets relay expiration timer reference" do
    timer_ref = make_ref()

    relay = %Relay{} |> Relay.put_timer_ref(timer_ref)

    assert relay.timer_ref == timer_ref
  end

  test "put_permissions/2 sets relay permissions" do
    permissions = %{{127, 0, 0, 1} => make_ref()}

    relay = %Relay{} |> Relay.put_permissions(permissions)

    assert relay.permissions == permissions
  end

  test "remove_permissions/2 deletes permission for given peer IP" do
    addr1 = {127, 0, 0, 1}
    addr2 = {172, 16, 0, 1}
    permissions = %{addr1 => make_ref(), addr2 => make_ref()}

    relay =
      %Relay{}
      |> Relay.put_permissions(permissions)
      |> Relay.remove_permission(addr1)
    permission_ips = Map.keys(relay.permissions)

    refute addr1 in permission_ips
    assert addr2 in permission_ips
  end

  test "has_permission?/2 check wheter there is permission for given peer" do
    addr1 = {127, 0, 0, 1}
    peer1 = {addr1, 12_345}
    addr2 = {172, 16, 0, 1}
    peer2 = {addr2, 12_345}
    permissions = %{addr1 => make_ref()}

    relay = %Relay{} |> Relay.put_permissions(permissions)

    assert Relay.has_permission?(relay, peer1)
    refute Relay.has_permission?(relay, peer2)
  end

  test "get_permission_timers/1 returns list of permission timers refs" do
    timer_ref1 = make_ref()
    timer_ref2 = make_ref()
    permissions = %{{127, 0, 0, 1} => timer_ref1}

    relay = %Relay{} |> Relay.put_permissions(permissions)
    timer_refs = Relay.get_permission_timers(relay)

    assert length(timer_refs) == 1
    assert timer_ref1 in timer_refs
    refute timer_ref2 in timer_refs
  end

  test "put_channel/2 adds a new channel if it wasn't present before" do
    peer = {{127, 0, 0, 1}, 12_345}
    channel_number = 0x4000
    channel = %Channel{peer: peer, number: channel_number,
                       timer_ref: make_ref()}

    relay = %Relay{} |> Relay.put_channel(channel)

    assert {:ok, channel} == Relay.get_channel_by_number(relay, channel_number)
    assert {:ok, channel} == Relay.get_channel_by_peer(relay, peer)
  end

  test "put_channel/3 maps channel with a given functon it is " <>
    "already present" do
    peer = {{127, 0, 0, 1}, 12_345}
    channel_number = 0x4000
    channel = %Channel{peer: peer, number: channel_number,
                       timer_ref: make_ref()}
    new_timer_ref = make_ref()

    relay =
      %Relay{}
      |> Relay.put_channel(channel)
      |> Relay.put_channel(channel, fn c -> %{c | timer_ref: new_timer_ref} end)

    updated_channel = %{channel | timer_ref: new_timer_ref}
    assert {:ok, updated_channel} ==
      Relay.get_channel_by_number(relay, channel_number)
    assert {:ok, updated_channel} == Relay.get_channel_by_peer(relay, peer)
  end

  test "remove_channel/3 deletes the channel from the relay" do
    peer = {{127, 0, 0, 1}, 12_345}
    channel_number = 0x4000
    channel = %Channel{peer: peer, number: channel_number,
                       timer_ref: make_ref()}
    relay =
      %Relay{}
      |> Relay.put_channel(channel)
      |> Relay.remove_channel(peer, channel_number)

    refute channel in Relay.get_channels(relay)
    assert :error == Relay.get_channel_by_number(relay, channel_number)
    assert :error == Relay.get_channel_by_peer(relay, peer)
  end

  test "get_channels/1 returns a list of all channels" do
    channel1 = %Channel{peer: {{127, 0, 0, 1}, 12_345}, number: 0x4000,
                        timer_ref: make_ref()}
    channel2 = %Channel{peer: {{172, 16, 0, 1}, 12_345}, number: 0x4001,
                        timer_ref: make_ref()}

    relay = %Relay{} |> Relay.put_channel(channel1)
    channels = Relay.get_channels(relay)

    assert length(channels) == 1
    assert channel1 in channels
    refute channel2 in channels
  end

  test "has_channel_bound?/2 returns true if there is channel for the " <>
    "given peer" do
    peer1 = {{127, 0, 0, 1}, 12_345}
    peer2 = {{172, 16, 0, 1}, 12_345}
    channel = %Channel{peer: peer1, number: 0x4000, timer_ref: make_ref()}

    relay = %Relay{} |> Relay.put_channel(channel)

    assert Relay.has_channel_bound?(relay, peer1)
    refute Relay.has_channel_bound?(relay, peer2)
  end

  describe "gen_channel_number/2" do
    test "returns :peer_locked if the peer is locked" do
      peer = {{127, 0, 0, 1}, 12_345}
      channel_number = 0x4000

      relay = %Relay{} |> Relay.lock_channel(peer, channel_number)

      assert {:error, :peer_locked} == Relay.gen_channel_number(relay, peer)
    end

    test "returns :capacity_reached if there are no more free channel numbers" do
      locked_range = 0x4000..0x5FFF
      taken_range = 0x6000..0x7FFF
      gen_peer = fn channel_number -> {{127, 0, 0, 1}, channel_number} end
      relay1 = Enum.reduce(locked_range, %Relay{}, fn number, relay ->
        Relay.lock_channel(relay, gen_peer.(number), number)
      end)
      relay2 = Enum.reduce(taken_range, relay1, fn number, relay ->
        channel = %Channel{number: number, peer: gen_peer.(number),
                          timer_ref: make_ref()}
        Relay.put_channel(relay, channel)
      end)

      assert {:error, :capacity_reached} == Relay.gen_channel_number(relay2,
        gen_peer.(12_345))
    end

    test "returns channel number if the peer has channel bound" do
      peer = {{127, 0, 0, 1}, 12_345}
      channel_number = 0x4000
      channel = %Channel{peer: peer, number: channel_number, timer_ref: make_ref}
      relay = %Relay{} |> Relay.put_channel(channel)

      assert {:ok, channel_number} == Relay.gen_channel_number(relay, peer)
    end

    test "returns new channel number if the peer does not have channel bound" do
      peer = {{127, 0, 0, 1}, 12_345}
      relay = %Relay{}

      assert {:ok, _} = Relay.gen_channel_number(relay, peer)
    end
  end

  test "lock and unlock channel" do
    peer = {{127, 0, 0, 1}, 12_345}
    channel_number = 0x4000

    relay1 = %Relay{} |> Relay.lock_channel(peer, channel_number)
    assert {:error, :peer_locked} = Relay.gen_channel_number(relay1, peer)

    relay2 = Relay.unlock_channel(relay1, peer, channel_number)
    assert {:ok, _} = Relay.gen_channel_number(relay2, peer)
  end

  test "add and remove lock timer reference" do
    timer_ref = make_ref()
    channel_number = 0x4000

    relay1 = %Relay{} |> Relay.put_lock_timer_ref(channel_number, timer_ref)
    assert timer_ref in Relay.get_lock_timer_refs(relay1)

    relay2 = %Relay{} |> Relay.remove_lock_timer_ref(channel_number)
    refute timer_ref in Relay.get_lock_timer_refs(relay2)
  end

end
