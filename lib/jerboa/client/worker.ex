defmodule Jerboa.Client.Worker do
  @moduledoc false

  use GenServer

  alias :gen_udp, as: UDP
  alias Jerboa.Params
  alias Jerboa.Client
  alias Jerboa.Client.Credentials
  alias Jerboa.Client.Relay
  alias Jerboa.Client.Relay.Permission
  alias Jerboa.Client.Protocol
  alias Jerboa.Client.Protocol.{Binding, Allocate, Refresh,
                                CreatePermission, Send, Data}
  alias Jerboa.Client.Transaction
  alias Jerboa.Client.DataHandler

  require Logger

  defstruct [:server, :socket, credentials: %Credentials{},
             relay: %Relay{}, transactions: %{}, data_handlers: %{}]

  @permission_expiry 5 * 60 * 1_000 # 5 minutes

  @type socket :: UDP.socket
  @type handler_target :: (peer :: Client.ip | :all)
  @type state :: %__MODULE__{
    server: Client.address,
    socket: socket,
    credentials: Credentials.t,
    transactions: %{transaction_id :: binary => Transaction.t},
    relay: Relay.t,
    data_handlers: %{handler_target => [DataHandler.t]}
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
    setup_logger_metadata(state)
    Logger.debug fn -> "Initialized client" end
    {:ok, state}
  end

  def handle_call(:bind, from, state) do
    {id, request} = Binding.request()
    Logger.debug fn -> "Sending binding request to the server" end
    send(request, state.server, state.socket)
    transaction = Transaction.new(from, id, binding_response_handler())
    {:noreply, add_transaction(state, transaction)}
  end
  def handle_call(:allocate, from, state) do
    if state.relay.address do
      Logger.debug fn ->
        "Allocation already present on the server, allocate request blocked"
      end
      {:reply, {:ok, state.relay.address}, state}
    else
      {id, request} = Allocate.request(state.credentials)
      Logger.debug fn -> "Sending allocate request to the server" end
      send(request, state.server, state.socket)
      transaction = Transaction.new(from, id, allocate_response_handler())
      {:noreply, add_transaction(state, transaction)}
    end
  end
  def handle_call(:refresh, from, state) do
    if state.relay.address do
      {id, request} = Refresh.request(state.credentials)
      Logger.debug fn -> "Sending refresh request to the server" end
      send(request, state.server, state.socket)
      transaction = Transaction.new(from, id, refresh_response_handler())
      {:noreply, add_transaction(state, transaction)}
    else
      Logger.debug fn ->
        "No allocation present on the server, refresh request blocked"
      end
      {:reply, {:error, :no_allocation}, state}
    end
  end
  def handle_call({:create_permission, peer_addrs}, from, state) do
    if state.relay.address do
      {id, request} = CreatePermission.request(state.credentials, peer_addrs)
      send(request, state.server, state.socket)
      transaction = Transaction.new(from, id, create_perm_response_handler())
      new_relay = state.relay |> add_permissions(peer_addrs, id)
      new_state = %{state | relay: new_relay} |> add_transaction(transaction)
      {:noreply, new_state}
    else
      Logger.debug fn ->
        "No allocation present on the server, create permission request blocked"
      end
      {:reply, {:error, :no_allocation}, state}
    end
  end
  def handle_call({:send, peer, data}, _, state) do
    formatted_peer = Client.format_address(peer)
    if has_permission?(state, peer) do
      indication = Send.indication(peer, data)
      Logger.debug "Sending data to #{formatted_peer} via send indication"
      send(indication, state.server, state.socket)
      {:reply, :ok, state}
    else
      Logger.debug "No permission installed for #{formatted_peer}, " <>
        "send indication blocked"
      {:reply, {:error, :no_permission}, state}
    end
  end
  def handle_call({:install_handler, peer, handler}, _, state) do
    {new_state, ref} = add_data_handler(state, peer, handler)
    {:reply, ref, new_state}
  end
  def handle_call({:remove_handler, reference}, _, state) do
    new_state = remove_data_handler(state, reference)
    {:reply, :ok, new_state}
  end

  def handle_cast(:persist, state) do
    indication = Binding.indication()
    Logger.debug fn -> "Sending binding indication to the server" end
    send(indication, state.server, state.socket)
    {:noreply, state}
  end

  def handle_info(:allocation_expired, state) do
    Logger.debug fn -> "Allocation timed out" end
    cancel_permission_timers(state.relay)
    new_state = %{state | relay: %Relay{}}
    {:noreply, new_state}
  end
  def handle_info({:permission_expired, peer_addr}, state) do
    Logger.debug fn -> "Permission for #{:inet.ntoa(peer_addr)} expired" end
    new_relay = state.relay |> remove_permission(peer_addr)
    {:noreply, %{state | relay: new_relay}}
  end
  def handle_info({:udp, socket, addr, port, packet},
    %{socket: socket, server: {addr, port}} = state) do
    params = Protocol.decode!(packet, state.credentials)
    new_state =
      case find_transaction(state, params.identifier) do
        nil ->
          handle_peer_data(state, params)
          state
        transaction ->
          state = handle_response(state, params, transaction)
          remove_transaction(state, transaction.id)
      end
    {:noreply, new_state}
  end

  def terminate(_, state) do
    :ok = UDP.close(state.socket)
  end

  ## Internals

  @spec send(packet :: binary, server :: Client.address, socket) :: state
  defp send(packet, server, socket) do
    {address, port} = server
    :ok = UDP.send(socket, address, port, packet)
  end

  @spec handle_response(state, Params.t, Transaction.t) :: state
  defp handle_response(state, params, transaction) do
    handler = transaction.handler
    {reply, creds, relay} = handler.(params, state.credentials, state.relay)
    GenServer.reply(transaction.caller, reply)
    %{state | credentials: creds, relay: relay}
  end

  @spec setup_logger_metadata(state) :: any
  defp setup_logger_metadata(%{socket: socket, server: server}) do
    {:ok, port} = :inet.port(socket)
    metadata = [jerboa_client: "#{inspect self()}:#{port}",
                jerboa_server: Client.format_address(server)]
    Logger.metadata(metadata)
  end

  @spec update_allocation_timer(Relay.t) :: Relay.t
  defp update_allocation_timer(relay) do
    timer_ref = relay.timer_ref
    lifetime = relay.lifetime
    if timer_ref do
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
        maybe_run_data_handlers(state, peer, data)
      :error ->
        Logger.debug "Received unprocessable STUN message"
    end
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
    fn params, creds, relay ->
      reply = Binding.eval_response(params)
      {reply, creds, relay}
    end
  end

  @spec allocate_response_handler :: Transaction.handler
  defp allocate_response_handler do
    fn params, creds, relay ->
      case Allocate.eval_response(params, creds) do
        {:ok, relayed_address, lifetime} ->
          Logger.debug fn ->
            "Received success allocate reponse, relayed address: " <>
              Client.format_address(relayed_address)
          end
          new_relay =
            relay
            |> Map.put(:address, relayed_address)
            |> Map.put(:lifetime, lifetime)
            |> update_allocation_timer()
          reply = {:ok, relayed_address}
          {reply, creds, new_relay}
        {:error, reason, new_creds} ->
          Logger.debug fn ->
            "Error when receiving allocate response, reason: #{inspect reason}"
          end
          reply = {:error, reason}
          {reply, new_creds, relay}
      end
    end
  end

  @spec refresh_response_handler :: Transaction.handler
  defp refresh_response_handler do
    fn params, creds, relay ->
      case Refresh.eval_response(params, creds) do
        {:ok, lifetime} ->
          Logger.debug fn ->
            "Received success refresh reponse, new lifetime: " <>
              "#{lifetime}"
          end
          new_relay =
            relay
            |> Map.put(:lifetime, lifetime)
            |> update_allocation_timer()
          {:ok, creds, new_relay}
        {:error, reason, new_creds} ->
          Logger.debug fn ->
            "Error when receiving refresh response, reason: #{inspect reason}"
          end
          reply = {:error, reason}
          {reply, new_creds, relay}
      end
    end
  end

  @spec create_perm_response_handler :: Transaction.handler
  defp create_perm_response_handler do
    fn params, creds, relay ->
      case CreatePermission.eval_response(params, creds) do
        :ok ->
          Logger.debug fn ->
            "Received success create permission reponse"
          end
          new_relay =
            relay
            |> update_permissions(params.identifier)
          {:ok, creds, new_relay}
        {:error, reason, new_creds} ->
          Logger.debug fn ->
            "Error when receiving create permission response, " <>
              "reason: #{inspect reason}"
          end
          reply = {:error, reason}
          {reply,  new_creds, relay}
      end
    end
  end

  ## Permissions

  @spec update_permissions(Relay.t, transaction_id :: binary) :: Relay.t
  defp update_permissions(relay, transaction_id) do
    new_perms =
      relay.permissions
      |> Enum.map(fn p -> update_permission(p, transaction_id) end)
    %{relay | permissions: new_perms}
  end

  @spec update_permission(Permission.t, transaction_id :: binary)
    :: Permission.t
  def update_permission(%{transaction_id: transaction_id} = perm,
    transaction_id) do
    if perm.acked?, do: Process.cancel_timer perm.timer_ref
    timer_ref = Process.send_after self(),
      {:permission_expired, perm.peer_address}, @permission_expiry
    %Permission{perm | acked?: true, timer_ref: timer_ref}
  end
  def update_permission(perm, _), do: perm

  @spec remove_permission(Relay.t, Client.ip) :: Relay.t
  defp remove_permission(relay, peer_addr) do
    {_, remaining} =
      Enum.split_with(relay.permissions,
        fn perm -> perm.peer_address == peer_addr end)
    %{relay | permissions: remaining}
  end

  @spec add_permissions(Relay.t, [Client.ip, ...], transaction_id :: binary)
    :: Relay.t
  defp add_permissions(relay, peer_addrs, transaction_id) do
    new_permissions =
        Enum.map peer_addrs, fn addr ->
          %Permission{peer_address: addr, transaction_id: transaction_id,
                      acked?: false}
      end
    %{relay | permissions: new_permissions ++ relay.permissions}
  end

  @spec has_permission?(state, peer :: Client.address) :: boolean
  defp has_permission?(state, {address, _port}) do
    Enum.any?(state.relay.permissions, fn perm ->
      perm.peer_address == address
    end)
  end

  @spec cancel_permission_timers(Relay.t) :: any
  defp cancel_permission_timers(relay) do
    relay.permissions
    |> Enum.each(fn p -> Process.cancel_timer(p.timer_ref) end)
  end

  ## Data handlers

  @spec maybe_run_data_handlers(state, Client.address, binary) :: any
  defp maybe_run_data_handlers(state, peer, data) do
    if has_permission?(state, peer) do
      run_handler = fn handler ->
        Task.start(fn -> run_data_handler(handler, peer, data) end)
      end

      {peer_addr, _} = peer

      state
      |> get_data_handlers_for(peer_addr)
      |> Enum.each(run_handler)

      state
      |> get_data_handlers_for(:all)
      |> Enum.each(run_handler)
    end
  end

  @spec get_data_handlers_for(state, handler_target) :: [DataHandler.t]
  defp get_data_handlers_for(state, peer_addr_or_all) do
    Map.get(state.data_handlers, peer_addr_or_all, [])
  end

  @spec run_data_handler(DataHandler.t, Client.address, binary) :: any
  defp run_data_handler(handler, peer, data) do
    handler.fun.(peer, data)
  end

  @spec add_data_handler(state, handler_target, Client.data_handler)
    :: {state, reference}
  defp add_data_handler(state, peer_or_all, handler_fun) do
    handler = DataHandler.new(handler_fun)
    new_handlers =
      Map.update(state.data_handlers, peer_or_all, [handler], & [handler | &1])
    {%{state | data_handlers: new_handlers}, handler.ref}
  end

  @spec remove_data_handler(state, reference) :: state
  defp remove_data_handler(state, reference) do
    new_data_handlers = Enum.reduce(state.data_handlers, %{},
      fn {target, handlers}, acc ->
        new_handlers = Enum.filter handlers, & &1.ref != reference
        case new_handlers do
          [] -> acc
          _  -> Map.put(acc, target, new_handlers)
        end
      end)
    %{state | data_handlers: new_data_handlers}
  end
end
