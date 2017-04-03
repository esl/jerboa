defmodule Jerboa.Client.Worker do
  @moduledoc false

  use GenServer

  alias :gen_udp, as: UDP
  alias Jerboa.Client
  alias Jerboa.Client.Protocol
  alias Jerboa.Client.Protocol.Transaction

  require Logger

  defstruct [:server, :socket, :mapped_address, :username, :secret,
             :realm, :nonce, :relayed_address, :lifetime, :lifetime_timer_ref,
             transaction: %Transaction{}]

  @default_retries 1

  @type socket :: UDP.socket
  @type state :: %__MODULE__{
    server: Client.address,
    socket: socket,
    transaction: Transaction.t,
    mapped_address: Client.address,
    username: String.t,
    secret: String.t,
    realm: String.t,
    nonce: String.t,
    relayed_address: Client.address,
    lifetime: non_neg_integer,
    lifetime_timer_ref: reference
  }

  @system_allocated_port 0

  @spec start_link(Client.start_opts) :: GenServer.on_start
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  ## GenServer callbacks

  def init(opts) do
    false = Process.flag(:trap_exit, true)
    {:ok, socket} = UDP.open(@system_allocated_port, [:binary, active: false])
    state = Protocol.init_state(opts, socket)
    setup_logger_metadata(state)
    Logger.debug fn -> "Initialized client" end
    {:ok, state}
  end

  def handle_call(:bind, _, state) do
    {result, new_state} =
      state
      |> Protocol.bind_req()
      |> send_req()
      |> Protocol.eval_bind_resp()
    {:reply, result, new_state}
  end
  def handle_call(:allocate, _, state) do
    if state.relayed_address do
      Logger.debug fn ->
        "Allocation already present on the server, allocate request blocked"
      end
      {:reply, {:ok, state.relayed_address}, state}
    else
      {result, new_state} = request_allocation(state, @default_retries)
      case result do
        {:ok, _} ->
          {:reply, result, update_lifetime_timer(new_state)}
        _ ->
          {:reply, result, new_state}
      end
    end
  end
  def handle_call(:refresh, _, state) do
    unless state.relayed_address do
      Logger.debug fn ->
        "No allocation present on the server, refresh request blocked"
      end
      {:reply, {:error, :no_allocation}, state}
    else
      {result, new_state} = request_refresh(state, @default_retries)
      case result do
        :ok ->
          {:reply, result, update_lifetime_timer(new_state)}
        _ ->
          {:reply, result, new_state}
      end
    end
  end

  def handle_cast(:persist, state) do
    state
    |> Protocol.bind_ind()
    |> send_ind()
    {:noreply, state}
  end

  def handle_info(:allocation_expired, state) do
    new_state = %{state | lifetime_timer_ref: nil,
                          relayed_address: nil,
                          lifetime: nil}
    {:noreply, new_state}
  end

  def terminate(_, state) do
    :ok = UDP.close(socket(state))
  end

  ## Internals

  defp server(%{server: server}), do: server

  defp socket(%{socket: socket}), do: socket

  @spec send_req(state) :: state
  defp send_req(%{transaction: %{req: req} = transaction} = state) do
    socket = socket(state)
    {address, port} = server(state)
    :ok = UDP.send(socket, address, port, req)
    {:ok, {^address, ^port, response}} = UDP.recv(socket, 0)
    %{state | transaction: %{transaction | resp: response}}
  end

  @spec send_ind(state) :: :ok
  defp send_ind(%{transaction: %{req: msg}} = state) do
    socket = socket(state)
    {address, port} = server(state)
    :ok = UDP.send(socket, address, port, msg)
  end

  @spec request_allocation(state, retries_left :: pos_integer)
    :: {result :: term, state}
  defp request_allocation(state, retries_left) do
    {result, new_state} =
      state
      |> Protocol.allocate_req()
      |> send_req()
      |> Protocol.eval_allocate_resp()
    with n when n > 0 <- retries_left,
         :retry <- result do
      Logger.debug fn -> "Received error allocate response, retrying.." end
      request_allocation(new_state, n - 1)
    else
      _ -> {result, new_state}
    end
  end

  @spec update_lifetime_timer(state) :: state
  defp update_lifetime_timer(state) do
    timer_ref = state.lifetime_timer_ref
    lifetime = state.lifetime
    if timer_ref do
      Process.cancel_timer timer_ref
    end
    if lifetime do
      new_ref = Process.send_after self(), :allocation_expired, lifetime * 1_000
      %{state | lifetime_timer_ref: new_ref}
    else
      state
    end
  end

  @spec request_refresh(state, retries_left :: pos_integer)
    :: {result :: term, state}
  defp request_refresh(state, retries_left) do
    {result, new_state} =
      state
      |> Protocol.refresh_req()
      |> send_req()
      |> Protocol.eval_refresh_resp()
    with n when n > 0 <- retries_left,
         :retry <- result do
      Logger.debug fn -> "Received error refresh response, retrying.." end
      request_refresh(new_state, n - 1)
    else
      _ -> {result, new_state}
    end
  end

  @spec setup_logger_metadata(state) :: any
  defp setup_logger_metadata(%{socket: socket, server: server}) do
    {:ok, port} = :inet.port(socket)
    metadata = [jerboa_client: "#{inspect self()}:#{port}",
                jerboa_server: Client.format_address(server)]
    Logger.metadata(metadata)
  end
end
