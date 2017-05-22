defmodule Jerboa.Client.Relay do
  @moduledoc false
  ## Data structure describing relay (allocation)

  alias Jerboa.Client
  alias Jerboa.Client.Relay.Channel
  alias Jerboa.Client.Relay.Channels
  alias Jerboa.Format

  @max_gen_channel_retries 10
  @min_channel_number 0x4000
  @max_channel_number 0x7FFF

  defstruct [:address, :lifetime, :timer_ref, permissions: %{},
             channels: %Channels{}]

  @type permissions :: %{Client.ip => timer_ref :: reference}
  @type t :: %__MODULE__{
    address:   nil | Client.address,
    lifetime:  nil | non_neg_integer,
    timer_ref: nil | reference,
    permissions: permissions,
    channels: %Channels{}
  }

  @spec active?(t) :: boolean
  def active?(relay), do: relay.address != nil

  @spec put_address(t, Client.address) :: t
  def put_address(relay, address), do: %__MODULE__{relay | address: address}

  @spec put_lifetime(t, lifetime :: non_neg_integer) :: t
  def put_lifetime(relay, lifetime), do: %__MODULE__{relay | lifetime: lifetime}

  @spec put_timer_ref(t, reference) :: t
  def put_timer_ref(relay, timer_ref) do
    %__MODULE__{relay | timer_ref: timer_ref}
  end

  @spec put_permissions(t, permissions) :: t
  def put_permissions(relay, permissions) do
    %__MODULE__{relay | permissions: permissions}
  end

  @spec remove_permission(t, Client.ip) :: t
  def remove_permission(relay, peer_addr) do
    permissions = Map.delete(relay.permissions, peer_addr)
    %__MODULE__{relay | permissions: permissions}
  end

  @spec has_permission?(t, peer :: Client.address) :: boolean
  def has_permission?(relay, {ip, _port}) do
    Enum.any?(relay.permissions, fn {peer_addr, _} ->
      peer_addr == ip
    end)
  end

  @spec get_permission_timers(t) :: [timer_ref :: reference]
  def get_permission_timers(relay) do
    relay.permissions
    |> Enum.map(fn {_, timer_ref} -> timer_ref end)
  end

  @spec put_channel(t, Channel.t, (Channel.t -> any)) :: t
  def put_channel(relay, channel, on_update \\ fn _ -> :ok end) do
    by_peer = Map.update(relay.channels.by_peer, channel.peer,
      channel, on_update)
    by_number = Map.update(relay.channels.by_number, channel.number,
      channel, on_update)
    channels = %Channels{relay.channels | by_peer: by_peer, by_number: by_number}
    %__MODULE__{relay | channels: channels}
  end

  @spec remove_channel(t, peer :: Client.address, Format.channel_number)
    :: t
  def remove_channel(relay, peer, channel_number) do
    by_peer = Map.delete(relay.channels.by_peer, peer)
    by_number = Map.delete(relay.channels.by_number, channel_number)
    channels = %Channels{relay.channels | by_peer: by_peer, by_number: by_number}
    %__MODULE__{relay | channels: channels}
  end

  @spec get_channels(t) :: [Channel.t]
  def get_channels(relay) do
    Map.values(relay.channels.by_peer)
  end

  @spec get_channel_by_peer(t, Client.address) :: {:ok, Channel.t} | :error
  def get_channel_by_peer(relay, peer) do
    Map.fetch(relay.channels.by_peer, peer)
  end

  @spec get_channel_by_number(t, Format.channel_number)
    :: {:ok, Channel.t} | :error
  def get_channel_by_number(relay, number) do
    Map.fetch(relay.channels.by_number, number)
  end

  @spec has_channel_bound?(t, Client.address) :: boolean
  def has_channel_bound?(relay, peer) do
    case get_channel_by_peer(relay, peer) do
      {:ok, _} -> true
      _ -> false
    end
  end

  @spec gen_channel_number(t, peer :: Client.address)
    :: {:ok, Format.channel_number}
     | {:error, :peer_locked | :capacity_reached | :retries_limit_reached}
  def gen_channel_number(relay, peer) do
    cond do
      MapSet.member?(relay.channels.locked_peers, peer) ->
        {:error, :peer_locked}
      channel_capacity_reached?(relay) ->
        {:error, :capacity_reached}
      true ->
        do_gen_channel_number(relay)
    end
  end

  @spec lock_channel(t, peer :: Client.address, Format.channel_number) :: t
  def lock_channel(relay, peer, channel_number) do
    locked_numbers = MapSet.put(relay.channels.locked_numbers, channel_number)
    locked_peers = MapSet.put(relay.channels.locked_peers, peer)
    channels = %Channels{relay.channels | locked_numbers: locked_numbers,
                         locked_peers: locked_peers}
    %__MODULE__{relay | channels: channels}
  end

  @spec unlock_channel(t, peer :: Client.address, Format.channel_number) :: t
  def unlock_channel(relay, peer, channel_number) do
    locked_numbers = MapSet.delete(relay.channels.locked_numbers, channel_number)
    locked_peers = MapSet.delete(relay.channels.locked_peers, peer)
    channels = %Channels{relay.channels | locked_numbers: locked_numbers,
                         locked_peers: locked_peers}
    %__MODULE__{relay | channels: channels}
  end

  @spec put_lock_timer_ref(t, Format.channel_number, timer_ref :: reference) :: t
  def put_lock_timer_ref(relay, channel_number, timer_ref) do
    lock_timer_refs = Map.put(relay.channels.lock_timer_refs,
      channel_number, timer_ref)
    channels = %Channels{relay.channels | lock_timer_refs: lock_timer_refs}
    %__MODULE__{relay | channels: channels}
  end

  @spec remove_lock_timer_ref(t, Format.channel_number) :: t
  def remove_lock_timer_ref(relay, channel_number) do
    lock_timer_refs = Map.delete(relay.channels.lock_timer_refs, channel_number)
    channels = %Channels{relay.channels | lock_timer_refs: lock_timer_refs}
    %__MODULE__{relay | channels: channels}
  end

  @spec get_lock_timer_refs(t) :: [timer_ref :: reference]
  def get_lock_timer_refs(relay) do
    Map.values(relay.channels.lock_timer_refs)
  end

  @spec do_gen_channel_number(t)
    :: {:ok, Format.channel_number} | {:error, :retries_limit_reached}
  defp do_gen_channel_number(_, retry \\ 1)
  defp do_gen_channel_number(_, retry) when retry == @max_gen_channel_retries do
    {:error, :retries_limit_reached}
  end
  defp do_gen_channel_number(relay, retry) do
    channel_number = random_channel_number()
    if channel_taken_or_locked?(relay, channel_number) do
      do_gen_channel_number(relay, retry + 1)
    else
      {:ok, channel_number}
    end
  end

  @spec random_channel_number :: Format.channel_number
  defp random_channel_number do
    :rand.uniform(@max_channel_number - @min_channel_number) +
      @min_channel_number
  end

  @spec channel_capacity_reached?(t) :: boolean
  defp channel_capacity_reached?(relay) do
    Enum.count(relay.channels.by_peer) ==
      @max_channel_number - @min_channel_number
  end

  @spec channel_taken_or_locked?(t, Format.channel_number) :: boolean
  defp channel_taken_or_locked?(relay, channel_number) do
     Map.has_key?(relay.channels.by_number, channel_number) or
       MapSet.member?(relay.channels.locked_numbers, channel_number)
  end
end
