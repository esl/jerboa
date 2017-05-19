defmodule Jerboa.Client.Worker do
  @moduledoc false

  use GenServer

  alias :gen_udp, as: UDP
  alias Jerboa.Params
  alias Jerboa.Client
  alias Jerboa.Client.Credentials
  alias Jerboa.Client.Relay
  alias Jerboa.Client.Protocol
  alias Jerboa.Client.Protocol.{Binding, Allocate, Refresh,
                                CreatePermission, Send, Data}
  alias Jerboa.Client.Transaction

  require Logger

  defstruct [:server, :socket, credentials: %Credentials{},
             relay: %Relay{}, transactions: %{}, subscriptions: %{}]

  @permission_expiry 5 * 60 * 1_000 # 5 minutes

  @type socket :: UDP.socket
  @type subscribers :: %{sub_pid :: pid => sub_ref :: reference}
  @type state :: %__MODULE__{
    server: Client.address,
    socket: socket,
    credentials: Credentials.t,
    transactions: %{transaction_id :: binary => Transaction.t},
    relay: Relay.t,
    subscriptions: %{Client.ip => subscribers}
  }

  @system_allocated_port 0

  @spec start_link(Client.start_opts) :: GenServer.on_start
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  ## GenServer callbacks

  def init(opts) do
    false = Process.flag(:trap_exit, true)
    {:ok, socket} = UDP.open(@system_allocated_port, [:binary, active: true])
    state = %__MODULE__{
      socket: socket,
      server: opts[:server],
      credentials: Credentials.initial(opts[:username], opts[:secret])
    }
    setup_logger_metadata(state.socket, state.server)
    _ = Logger.debug "Initialized client"
    {:ok, state}
  end

  def handle_call(:bind, from, state) do
    {id, request} = Binding.request()
    _ = Logger.debug "Sending binding request to the server"
    send(request, state.server, state.socket)
    transaction = Transaction.new(from, id, binding_response_handler())
    {:noreply, add_transaction(state, transaction)}
  end
  def handle_call({:allocate, opts}, from, state) do
    if state.relay.address do
      _ = Logger.debug "Allocation already present on the server, " <>
        "allocate request blocked"
      {:reply, {:ok, state.relay.address}, state}
    else
      {id, request} = Allocate.request(state.credentials, opts)
      _ = Logger.debug "Sending allocate request to the server"
      send(request, state.server, state.socket)
      transaction = Transaction.new(from, id, allocate_response_handler(opts))
      {:noreply, add_transaction(state, transaction)}
    end
  end
  def handle_call(:refresh, from, state) do
    if state.relay.address do
      {id, request} = Refresh.request(state.credentials)
      _ = Logger.debug "Sending refresh request to the server"
      send(request, state.server, state.socket)
      transaction = Transaction.new(from, id, refresh_response_handler())
      {:noreply, add_transaction(state, transaction)}
    else
      _ = Logger.debug "No allocation present on the server, " <>
        "refresh request blocked"
      {:reply, {:error, :no_allocation}, state}
    end
  end
  def handle_call({:create_permission, peer_addrs}, from, state) do
    if state.relay.address do
      {id, request} = CreatePermission.request(state.credentials, peer_addrs)
      send(request, state.server, state.socket)
      context = %{peer_addrs: peer_addrs}
      transaction = Transaction.new(from, id, create_perm_response_handler(),
        context)
      {:noreply, state |> add_transaction(transaction)}
    else
      _ = Logger.debug "No allocation present on the server, " <>
        "create permission request blocked"
      {:reply, {:error, :no_allocation}, state}
    end
  end
  def handle_call({:send, peer, data}, _, state) do
    formatted_peer = Client.format_address(peer)
    if has_permission?(state, peer) do
      indication = Send.indication(peer, data)
      _ = Logger.debug fn ->
        "Sending data to #{formatted_peer} via send indication"
      end
      send(indication, state.server, state.socket)
      {:reply, :ok, state}
    else
      _ = Logger.debug "No permission installed for #{formatted_peer}, " <>
        "send indication blocked"
      {:reply, {:error, :no_permission}, state}
    end
  end
  def handle_call({:subscribe, sub_pid, peer_addr}, _, state) do
    sub_ref = Process.monitor(sub_pid)
    new_state = add_subscription(state, peer_addr, sub_pid, sub_ref)
    {:reply, :ok, new_state}
  end
  def handle_call({:unsubscribe, sub_pid, peer_addr}, _, state) do
    new_state = remove_subscription(state, peer_addr, sub_pid)
    {:reply, :ok, new_state}
  end

  def handle_cast(:persist, state) do
    indication = Binding.indication()
    _ = Logger.debug "Sending binding indication to the server"
    send(indication, state.server, state.socket)
    {:noreply, state}
  end

  def handle_info(:allocation_expired, state) do
    _ = Logger.debug "Allocation timed out"
    cancel_permission_timers(state.relay)
    new_state = %{state | relay: %Relay{}}
    {:noreply, new_state}
  end
  def handle_info({:permission_expired, peer_addr}, state) do
    _ = Logger.debug fn -> "Permission for #{:inet.ntoa(peer_addr)} expired" end
    new_relay = state.relay |> remove_permission(peer_addr)
    {:noreply, %{state | relay: new_relay}}
  end
  def handle_info({:udp, socket, addr, port, packet},
    %{socket: socket, server: {addr, port}} = state) do
    params = Protocol.decode!(packet, state.credentials)
    new_state =
      case find_transaction(state, params.identifier) do
        nil ->
          _ = handle_peer_data(state, params)
          state
        transaction ->
          state = handle_response(state, params, transaction)
          remove_transaction(state, transaction.id)
      end
    {:noreply, new_state}
  end
  def handle_info({:DOWN, ref, _, _, _}, state) do
    new_state = remove_subscription(state, ref)
    {:noreply, new_state}
  end

  def terminate(_, state) do
    :ok = UDP.close(state.socket)
    _ = Logger.debug "Terminating"
  end

  ## Internals

  @spec send(packet :: binary, server :: Client.address, socket) :: :ok
  defp send(packet, server, socket) do
    {address, port} = server
    :ok = UDP.send(socket, address, port, packet)
  end

  @spec handle_response(state, Params.t, Transaction.t) :: state
  defp handle_response(state, params, transaction) do
    handler = transaction.handler
    {reply, creds, relay} = handler.(params, state.credentials, state.relay,
      transaction.context)
    GenServer.reply(transaction.caller, reply)
    %{state | credentials: creds, relay: relay}
  end

  @spec setup_logger_metadata(UDP.socket, Client.address) :: :ok
  defp setup_logger_metadata(socket, server) do
    {:ok, port} = :inet.port(socket)
    metadata = [jerboa_client: "#{inspect self()}:#{port}",
                jerboa_server: Client.format_address(server)]
    Logger.metadata(metadata)
  end

  @spec update_allocation_timer(Relay.t) :: Relay.t
  defp update_allocation_timer(relay) do
    timer_ref = relay.timer_ref
    lifetime = relay.lifetime
    _ = if timer_ref do
      Process.cancel_timer timer_ref
    end
    if lifetime do
      new_ref = Process.send_after self(), :allocation_expired, lifetime * 1_000
      %{relay | timer_ref: new_ref}
    else
      relay
    end
  end

  @spec handle_peer_data(state, Params.t) :: any
  defp handle_peer_data(state, params) do
    case Data.eval_indication(params) do
      {:ok, peer, data} ->
        maybe_notify_subscribers(state, peer, data)
      :error ->
        _ = Logger.debug "Received unprocessable STUN message"
    end
  end

  @spec maybe_notify_subscribers(state, Client.address, binary) :: any
  defp maybe_notify_subscribers(state, peer, data) do
    if has_permission?(state, peer) do
      notify_subscribers(state, peer, data)
    end
  end

  @spec notify_subscribers(state, Client.address, binary) :: any
  defp notify_subscribers(state, peer, data) do
    {peer_addr, _} = peer
    state.subscriptions
    |> Map.get(peer_addr, [])
    |> Enum.each(fn {sub_pid, _} ->
      send sub_pid, {:peer_data, self(), peer, data}
    end)
  end

  ## Transactions

  @spec add_transaction(state, Transaction.t) :: state
  defp add_transaction(state, t) do
    new_transactions = Map.put(state.transactions, t.id, t)
    %{state | transactions: new_transactions}
  end

  @spec find_transaction(state, id :: binary) :: Transaction.t | nil
  defp find_transaction(state, id) do
    Map.get(state.transactions, id, nil)
  end

  @spec remove_transaction(state, id :: binary) :: state
  defp remove_transaction(state, id) do
    new_transactions = Map.delete(state.transactions, id)
    %{state | transactions: new_transactions}
  end

  ## Transaction handlers

  @spec binding_response_handler :: Transaction.handler
  defp binding_response_handler do
    fn params, creds, relay, _ ->
      reply = Binding.eval_response(params)
      case reply do
        {:ok, mapped_address} ->
          _ = Logger.debug fn ->
            "Received success binding response, mapped address: " <>
              Client.format_address(mapped_address)
          end
        {:error, reason} ->
          _ = Logger.debug fn ->
            "Error when receiving binding response, reason: #{inspect reason}"
          end
      end
      {reply, creds, relay}
    end
  end

  @spec allocate_response_handler(Client.allocate_opts) :: Transaction.handler
  defp allocate_response_handler(opts) do
    fn params, creds, relay, _ ->
      case Allocate.eval_response(params, creds, opts) do
        {:ok, relayed_address, lifetime, reservation_token} ->
          handle_allocate_success_with_token(relayed_address, lifetime,
            reservation_token, relay, creds)
        {:ok, relayed_address, lifetime} ->
          handle_allocate_success(relayed_address, lifetime, relay, creds)
        {:error, reason, new_creds} ->
          _ = Logger.debug fn ->
            "Error when receiving allocate response, reason: #{inspect reason}"
          end
          reply = {:error, reason}
          {reply, new_creds, relay}
      end
    end
  end

  @spec handle_allocate_success_with_token(Client.address, non_neg_integer,
    binary, Relay.t, Credentials.t) :: {term, Credentials.t, Relay.t}
  defp handle_allocate_success_with_token(relayed_address, lifetime,
    reservation_token, relay, creds) do
    _ = Logger.debug fn ->
      "Received success allocate reponse with reservation token, " <>
        "relayed address: " <> Client.format_address(relayed_address)
    end
    new_relay = init_new_relay(relay, relayed_address, lifetime)
    reply = {:ok, relayed_address, reservation_token}
    {reply, creds, new_relay}
  end

  @spec handle_allocate_success(Client.address, non_neg_integer, Relay.t,
    Credentials.t) :: {term, Credentials.t, Relay.t}
  defp handle_allocate_success(relayed_address, lifetime,
    relay, creds) do
    _ = Logger.debug fn ->
      "Received success allocate reponse, relayed address: " <>
        Client.format_address(relayed_address)
    end
    new_relay = init_new_relay(relay, relayed_address, lifetime)
    reply = {:ok, relayed_address}
    {reply, creds, new_relay}
  end

  defp init_new_relay(old_relay, relayed_address, lifetime) do
    old_relay
    |> Map.put(:address, relayed_address)
    |> Map.put(:lifetime, lifetime)
    |> update_allocation_timer()
  end

  @spec refresh_response_handler :: Transaction.handler
  defp refresh_response_handler do
    fn params, creds, relay, _ ->
      case Refresh.eval_response(params, creds) do
        {:ok, lifetime} ->
          _ = Logger.debug fn ->
            "Received success refresh reponse, new lifetime: " <>
              "#{lifetime}"
          end
          new_relay =
            relay
            |> Map.put(:lifetime, lifetime)
            |> update_allocation_timer()
          {:ok, creds, new_relay}
        {:error, reason, new_creds} ->
          _ = Logger.debug fn ->
            "Error when receiving refresh response, reason: #{inspect reason}"
          end
          reply = {:error, reason}
          {reply, new_creds, relay}
      end
    end
  end

  @spec create_perm_response_handler :: Transaction.handler
  defp create_perm_response_handler do
    fn params, creds, relay, %{peer_addrs: peer_addrs} ->
      case CreatePermission.eval_response(params, creds) do
        :ok ->
          _ = Logger.debug "Received success create permission reponse"
          new_relay =
            relay
            |> add_permissions(peer_addrs)
          {:ok, creds, new_relay}
        {:error, reason, new_creds} ->
          _ = Logger.debug fn ->
            "Error when receiving create permission response, " <>
              "reason: #{inspect reason}"
          end
          reply = {:error, reason}
          {reply,  new_creds, relay}
      end
    end
  end

  @spec remove_permission(Relay.t, Client.ip) :: Relay.t
  defp remove_permission(relay, peer_addr) do
    permissions = Map.delete(relay.permissions, peer_addr)
    %{relay | permissions: permissions}
  end

  @spec add_permissions(Relay.t, [Client.ip, ...])
    :: Relay.t
  defp add_permissions(relay, peer_addrs) do
    new_permissions =
      peer_addrs
      |> Stream.map(fn peer_addr ->
        timer_ref = Process.send_after self(),
          {:permission_expired, peer_addr}, @permission_expiry
      {peer_addr, timer_ref}
      end)
      |> Enum.into(%{})
    permissions = Map.merge(relay.permissions, new_permissions,
      fn _, old_ref, new_ref ->
        _ = Process.cancel_timer old_ref
        new_ref
      end)
    %{relay | permissions: permissions}
  end

  @spec has_permission?(state, peer :: Client.address) :: boolean
  defp has_permission?(state, {address, _port}) do
    Enum.any?(state.relay.permissions, fn {peer_addr, _} ->
      peer_addr == address
    end)
  end

  @spec cancel_permission_timers(Relay.t) :: any
  defp cancel_permission_timers(relay) do
    relay.permissions
    |> Enum.each(fn {_, timer_ref} ->
      Process.cancel_timer(timer_ref)
    end)
  end

  ## Subscriptions

  @spec add_subscription(state, Client.ip, pid, reference) :: state
  defp add_subscription(state, peer_addr, sub_pid, sub_ref) do
    new_subscriptions =
      state.subscriptions
      |> Map.update(peer_addr, %{sub_pid => sub_ref}, fn subs ->
        update_subscriber_ref(subs, sub_pid, sub_ref)
      end)
    %{state | subscriptions: new_subscriptions}
  end

  @spec update_subscriber_ref(subscribers, pid, reference) :: subscribers
  defp update_subscriber_ref(subscribers, sub_pid, sub_ref) do
    case Map.fetch(subscribers, sub_pid) do
      {:ok, old_ref} ->
        Process.demonitor(old_ref)
      _ ->
        :ok
    end
    Map.put(subscribers, sub_pid, sub_ref)
  end

  @spec remove_subscription(state, Client.ip, pid) :: state
  defp remove_subscription(state, peer_addr, sub_pid) do
    subscribers = state.subscriptions[peer_addr]
    case subscribers do
      nil ->
        state
      _ ->
        new_subscribers = remove_subscriber(subscribers, sub_pid)
        update_subscriptions(state, peer_addr, new_subscribers)
    end
  end

  @spec remove_subscription(state, sub_ref :: reference) :: state
  defp remove_subscription(state, sub_ref) do
    new_subscriptions =
      state.subscriptions
      |> Enum.reduce(%{}, fn {peer_addr, subscribers}, acc ->
        new_subscribers = remove_subscriber(subscribers, sub_ref)
        maybe_put_subscribers(acc, peer_addr, new_subscribers)
      end)
    %{state | subscriptions: new_subscriptions}
  end

  @spec remove_subscriber(subscribers, pid | reference) :: subscribers
  defp remove_subscriber(subscribers, sub_pid) when is_pid(sub_pid) do
    Map.delete(subscribers, sub_pid)
  end
  defp remove_subscriber(subscribers, sub_ref) when is_reference(sub_ref) do
    subscribers
    |> Enum.reject(fn {_, ref} -> ref == sub_ref end)
    |> Enum.into(%{})
  end

  @spec update_subscriptions(state, Client.ip, subscribers) :: state
  defp update_subscriptions(state, peer_addr, subscribers) do
    new_subscriptions =
      if Enum.empty?(subscribers) do
        Map.delete(state.subscriptions, peer_addr)
      else
        Map.put(state.subscriptions, peer_addr, subscribers)
      end
    %{state | subscriptions: new_subscriptions}
  end

  @spec maybe_put_subscribers(%{Client.ip => subscribers}, Client.ip, subscribers)
    :: %{Client.ip => subscribers}
  defp maybe_put_subscribers(subscriptions, peer_addr, subscribers) do
    if Enum.empty?(subscribers) do
      subscriptions
      else
        Map.put(subscriptions, peer_addr, subscribers)
      end
  end
end
