defmodule Jerboa.Client.Worker do
  @moduledoc false

  use GenServer

  alias :gen_udp, as: UDP
  alias Jerboa.Client
  alias Jerboa.Client.Protocol
  alias Jerboa.Client.Protocol.Transaction

  defstruct [:server, :socket, :mapped_address, :username, :secret,
             :realm, :nonce, :relayed_address, :lifetime,
             transaction: %Transaction{}]

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
    lifetime: non_neg_integer
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
      {:reply, {:ok, state.relayed_address}, state}
    else
      {result, new_state} = request_allocation(state)
      {:reply, result, new_state}
    end
  end

  def handle_cast(:persist, state) do
    state
    |> Protocol.bind_ind()
    |> send_ind()
    {:noreply, state}
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
    {:ok, {^address, ^port, response}} = UDP.recv(socket, 0, timeout())
    %{state | transaction: %{transaction | resp: response}}
  end

  @spec send_ind(state) :: :ok
  defp send_ind(%{transaction: %{req: msg}} = state) do
    socket = socket(state)
    {address, port} = server(state)
    :ok = UDP.send(socket, address, port, msg)
  end

  defp timeout do
    Keyword.fetch!(Application.fetch_env!(:jerboa, :client), :timeout)
  end

  @spec request_allocation(state) :: {result :: term, state}
  defp request_allocation(state) do
    {result, new_state} =
      state
      |> Protocol.allocate_req()
      |> send_req()
      |> Protocol.eval_allocate_resp()
    case result do
      :retry ->
        request_allocation(new_state)
      _ ->
        {result, new_state}
    end
  end
end
