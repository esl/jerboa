defmodule Jerboa.Client do
  @moduledoc """
  STUN client process

  Use `start/1` function to spawn new client process:

      iex> Jerboa.Client.start server: %{address: server_ip, port: server_port}
      {:ok, #PID<...>}

  (see `start/1` for configuration options)

  ## Requesting server reflexive address

  The `bind/1` issues a Binding request to a server and returns reflexive IP address and port.
  If returned message is not a valid STUN message or it doesn't include XOR Mapped Address
  attribute, the client simply crashes.

      iex> Jerboa.Client.bind client_pid
      {:ok, {{192, 168, 1, 20}, 32780}}

  `persist/1` sends a Binding indication to a server, which is not meant to return
  any response, but is an attempt to refresh NAT bindings in routers on the path to a server.
  Note that this is only an attempt, there is no guarantee that some router on the path
  won't rebind client's inside address and port.

  ## Creating allocations

  Allocation is a logical communication path between one client and multiple peers.
  In practice a socket is created on the server, which peers can send data to,
  and the server will forward this data to the client. Client can send data to
  the server which will forward it to one or more peers.

  Refer to [TURN RFC](https://trac.tools.ietf.org/html/rfc5766#section-2)
  for a more detailed description.

  `allocate/1` is used to request an allocation on the server. On success it returns
  an `:ok` tuple, which contains allocated IP address and port number. Jerboa won't
  try to request an allocation if it knows that the client already has one.

  Note that allocations have an expiration time (RFC recommends 10 minutes), To refresh
  an existing allocation one can use `refresh/1`.

  ## Logging

  Client logs progress messages with `:debug` level, so Elixir's Logger needs to
  be configured first to see them. It is recommended to allow Jerboa logging metadata,
  i.e. `:jerboa_client` and `:jerboa_server`:

      config :logger,
        level: :debug,
        metadata: [:jerboa_client, :jerboa_server]
  """

  @type t :: pid
  @type port_no :: :inet.port_number
  @type ip :: :inet.ip4_address
  @type address :: {ip, port_no}
  @type start_opts :: [start_opt]
  @type start_opt :: {:server, address}
                   | {:username, String.t}
                   | {:secret, String.t}
  @type allocate_opts :: [allocate_opt]
  @type allocate_opt :: {:even_port, boolean}
  @type error :: :bad_response
               | :no_allocation
               | Jerboa.Format.Body.Attribute.ErrorCode.name

  alias Jerboa.Client

  @doc ~S"""
  Starts STUN client process

      iex> opts = [server: {{192, 168, 1, 20}, 3478}, username: "user", secret: "abcd"]
      iex> Jerboa.Client.start(opts)
      {:ok, #PID<...>}

  ### Options

  * `:server` - required - a tuple with server's address and port
  * `:username` - required - username used for authentication
  * `:secret` - required - secret used for authentication
  """
  @spec start(options :: Keyword.t) :: Supervisor.on_start_child
  def start(opts) do
    Supervisor.start_child(Client.Supervisor, [opts])
  end

  @doc """
  Sends Binding request to a server

  Returns reflexive address and port on successful response. Returns
  error tuple if response from the server is invalid. Client process
  crashes if response is not a valid STUN message.
  """
  @spec bind(t) :: {:ok, address} | {:error, :bad_response} | no_return
  def bind(client) do
    request(client, :bind).()
  end

  @doc """
  Sends Binding indication to a server
  """
  @spec persist(t) :: :ok
  def persist(client) do
    GenServer.cast(client, :persist)
  end

  @doc """
  Creates allocation on the server or returns relayed transport
  address if client already has an allocation

  ## Options

  * `:even_port` - optional - if set to `true`, EVEN-PORT attribute
    will be included in the request, which prompts the server to
    allocate even port number
  """
  @spec allocate(t) :: {:ok, address} | {:error, error}
  @spec allocate(t, allocate_opts) :: {:ok, address} | {:error, error}
  def allocate(client, opts \\ []) do
    call = request(client, {:allocate, opts})
    case call.() do
      {:error, :stale_nonce} -> call.()
      {:error, :unauthorized} -> call.()
      result -> result
    end
  end

  @doc """
  Tries to refresh the allocation on the server
  """
  @spec refresh(t) :: :ok | {:error, error}
  def refresh(client) do
    maybe_retry(client, :refresh)
  end

  @doc """
  Creates permissions on the allocation for the given peer
  addresses

  If permission is already installed for the given address,
  the permission will be refreshed.

  ## Examples

      create_permission client, {192, 168, 22, 111}

      create_permission client, [{192, 168, 22, 111}, {212, 168, 33, 222}]
  """
  @spec create_permission(t, peers :: ip | [ip, ...]) :: :ok | {:error, error}
  def create_permission(_client, []), do: :ok
  def create_permission(client, peers) when is_list(peers) do
    maybe_retry(client, {:create_permission, peers})
  end
  def create_permission(client, peer), do: create_permission(client, [peer])

  @doc """
  Sends data to a given peer

  Note that there are no guarantees that the data sent reaches
  the peer. TURN servers don't acknowledge Send indications.
  """
  @spec send(t, peer :: address, data :: binary)
    :: :ok | {:error, :no_permission}
  def send(client, peer, data) do
    request(client, {:send, peer, data}).()
    end

  @doc """
  Subscribes PID to data received from the given peer

  Message format is
      {:peer_data, client_pid :: pid, peer :: address, data :: binary}
  """
  @spec subscribe(t, sub :: pid, peer_addr :: ip) :: :ok
  def subscribe(client, pid, peer_addr) do
    request(client, {:subscribe, pid, peer_addr}).()
  end

  @doc """
  Subscribes calling process to data received from the given peer

  Message format is
      {:peer_data, client_pid :: pid, peer :: address, data :: binary}
  """
  @spec subscribe(t, peer_addr :: ip) :: :ok
  def subscribe(client, peer_addr) do
    subscribe(client, self(), peer_addr)
  end

  @doc """
  Cancels subscription of given PID
  """
  @spec unsubscribe(t, sub :: pid, peer_addr :: ip) :: :ok
  def unsubscribe(client, pid, peer_addr) do
    request(client, {:unsubscribe, pid, peer_addr}).()
  end

  @doc """
  Cancels subscription of calling process
  """
  @spec unsubscribe(t, peer_addr :: ip) :: :ok
  def unsubscribe(client, peer_addr) do
    unsubscribe(client, self(), peer_addr)
  end

  @doc """
  Blocks the calling process until it receives the data from the given
  peer

  Calling process needs to be subscribed to this peer's data
  before calling this function, otherwise it will always time out.

  Accepts timeout in milliseconds as optional argument (defualt is 5000),
  may be also atom `:infinity`.

  This function simply uses subscriptions mechanism.
  It implies lack of knowledge about permissions installed for the given
  peer, thus if there is no permission, the function will most likely
  time out.
  """
  @spec recv(t, peer_addr :: Client.ip)
  :: {:ok, peer :: Client.address, data :: binary} | {:error, :timeout}
  def recv(client, peer_addr, timeout \\ 5_000) do
    receive do
      {:peer_data, ^client, {^peer_addr, _} = peer, data} ->
        {:ok, peer, data}
    after
      timeout ->
        {:error, :timeout}
    end
  end

  @doc """
  Stops the client
  """
  @spec stop(t) :: :ok | {:error, error}
    when error: :not_found | :simple_one_for_one
  def stop(client) do
    Supervisor.terminate_child(Client.Supervisor, client)
  end

  @doc false
  @spec format_address(address) :: String.t
  def format_address({ip, port}) do
    "#{:inet.ntoa(ip)}:#{port}"
  end

  @spec request(t, term) :: (() -> {:error, error} | term)
  defp request(client, req), do: fn -> GenServer.call(client, req) end

  @spec maybe_retry(t, request) :: {:error, error} | term when
    request: :allocate | :refresh | {:create_permission, [Client.ip, ...]}
  defp maybe_retry(client, req) do
    call = request(client, req)
    case call.() do
      {:error, :stale_nonce} ->
        call.()
      result ->
        result
    end
  end
end
