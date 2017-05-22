defmodule Jerboa.Client.Relay do
  @moduledoc false
  ## Data structure describing relay (allocation)

  alias Jerboa.Client
  alias Jerboa.Client.Channel
  alias Jerboa.Format

  defstruct [:address, :lifetime, :timer_ref, permissions: %{},
             channels: {%{}, %{}}]

  @type permissions :: %{Client.ip => timer_ref :: reference}
  @type t :: %__MODULE__{
    address:   nil | Client.address,
    lifetime:  nil | non_neg_integer,
    timer_ref: nil | reference,
    permissions: permissions,

    ## `:channels` is a tuple of two maps, which have the same values,
    ## but under different keys. The first one's keys are peer adresses
    ## bound to channels, the other one's keys are channel numbers of
    ## those channels. The values in both are Channel structs.
    channels: {%{peer :: Client.address => Channel.t},
               %{Format.channel_number  => Channel.t}}
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

  @spec remove_permission(Relay.t, Client.ip) :: Relay.t
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

  @spec get_permission_timers(Relay.t) :: [timer_ref :: reference]
  def get_permission_timers(relay) do
    relay.permissions
    |> Enum.map(fn {_, timer_ref} -> timer_ref end)
  end

  @spec put_channel(t, Channel.t, (Channel.t -> any)) :: t
  def put_channel(relay, channel, on_update \\ fn _ -> :ok end) do
    {peer_to_channel, number_to_channel} = relay.channels
    channels =
      {Map.update(peer_to_channel, channel.peer, channel, on_update),
       Map.update(number_to_channel, channel.number,
         channel, on_update)}
    %__MODULE__{relay | channels: channels}
  end

  @spec remove_channel(t, peer :: Client.address, Format.channel_number)
    :: Relay.t
  def remove_channel(relay, peer, channel_number) do
    {peer_to_channel, number_to_channel} = relay.channels
    channels = {Map.delete(peer_to_channel, peer),
                Map.delete(number_to_channel, channel_number)}
    %__MODULE__{relay | channels: channels}
  end

  @spec get_channels(t) :: [Channel.t]
  def get_channels(relay) do
    {peer_to_channel, _} = relay.channels
    Map.values(peer_to_channel)
  end

  @spec get_channel_by_peer(t, Client.address) :: {:ok, Channel.t} | :error
  def get_channel_by_peer(relay, peer) do
    {peer_to_channel, _} = relay.channels
    Map.fetch(peer_to_channel, peer)
  end

  @spec get_channel_by_number(t, Format.channel_number)
    :: {:ok, Channel.t} | :error
  def get_channel_by_number(relay, number) do
    {_, number_to_channel} = relay.channels
    Map.fetch(number_to_channel, number)
  end

  @spec has_channel_bound?(t, Client.address) :: boolean
  def has_channel_bound?(relay, peer) do
    case get_channel_by_peer(relay, peer) do
      {:ok, _} -> true
      _ -> false
    end
  end
end
