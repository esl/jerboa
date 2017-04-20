defmodule Jerboa.Client do
  @moduledoc ~S"""
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

  ## Creating permissions

  In order to exchange data with a peer using relay on a TURN server, TURN client must create
  a permission for the peer first (otherwise any third-party could send data to a client via relay).
  Creating permissions is done with `create_permission/2`. This functions accepts an IP address
  or a list of IP addresses and installs permissions for those addresses on a TURN server.

  Note that addresses passed to this function should be server reflexive (most likely
  resolved by some kind of signalling - see ICE RFC for more information), i.e. the TURN
  server will allow to relay data to and from these addresses without any attempt of
  NAT translations.

      iex> Jerboa.Client.create_permission client, {192, 168, 0, 27}

  ## Exchanging data

  Once we have installed permissions for some IP address, we can send and receive data from
  any port bound to that address (please note again - the address as seen by the server).

  To send data you can use simple `send/3` call. This function accepts peer's IP address and port
  and data to be sent. Jerboa won't allow you to send data to a peer if you haven't installed
  permission for it.

      iex> Jerboa.Client.send client, {{192, 168, 0, 27}, 12345}, "Hello, Mike!"


  There are two simple ways to receive data from peers: `recv/2` and `stream_to/3`. `recv/2`
  is a blocking function which will wait for the data sent by the peer whose address is passed
  as argument.

      iex> Jerboa.Client.recv client, {192, 168, 0, 27}
      {:ok, {{192, 168, 0, 27}, 12345}, "Alice has a cat"}

  `stream_to/3` allows you pass the PID which will be sent data received by the client process
  from the given peer. You can call `stream_to/3` multiple times with different target PIDs.

      iex> Jerboa.Client.stream_to client, self(), {192, 168, 0, 27}
      iex> flush()
      {:peer_data, {{192, 168, 0, 27}, 12345}, "Alice has a cat"}

  ## Advanced data handling

  If `recv/2` and `stream_to/3` is not enough for handling incoming data, you can install
  custom data handlers using `install_handler/3`. This function takes a peer IP address
  and a anonymous function which will be called every time data is received from the given peer.
  The anonymous function must accept two arguments: first is a tuple with peer's IP address and port,
  and second is a received binary.

  For example, if you'd like to log every incoming packet, you could install following handler:

      iex> Jerboa.Client.install_handler client, {192, 168, 0, 27}, fn _, data -> Logger.debug "Received data: #{data}" end

  There is also `install_handler/2` function, which will install handler for all peers.

  Note that handlers will be called only if there is a permission installed for the peer
  who is the source of a data.

  Both versions of `install_handler` return a reference which can be later used to remove handlers
  using `remove_handler/2`.

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
  @type ip :: :inet.ip_address
  @type address :: {ip, port_no}
  @type data_handler :: (peer :: address, data :: binary -> term)
  @type start_opts :: [start_opt]
  @type start_opt :: {:server, address}
                   | {:username, String.t}
                   | {:secret, String.t}
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
  """
  @spec allocate(t) :: {:ok, address} | {:error, error}
  def allocate(client) do
    call = request(client, :allocate)
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
  Installs handler for data received from given peer

  Returns a reference which may be used later to delete the handler
  from the client. The handler won't be deleted after data is received.
  """
  @spec install_handler(t, peer :: ip, data_handler) :: reference
  def install_handler(client, peer, handler) do
    request(client, {:install_handler, peer, handler}).()
  end

  @doc """
  Installs handler for data received from all peers
  """
  @spec install_handler(t, data_handler) :: reference
  def install_handler(client, handler) do
    request(client, {:install_handler, :all, handler}).()
  end

  @doc """
  Removes previously installed handler
  """
  @spec remove_handler(t, reference) :: :ok
  def remove_handler(client, reference) do
    request(client, {:remove_handler, reference}).()
  end

  @doc """
  Waits for data from the given peer

  It accepts peer address and desired timeout in milliseconds.
  Default timeout is 5000.
  """
  @spec recv(t, peer_addr :: ip, timeout :: non_neg_integer | :infinity)
    :: {:ok, peer :: address, binary} | {:error, :timeout}
  def recv(client, peer_addr, timeout \\ 5000) do
    ref = make_ref()
    receiver = self()
    handler_ref = install_handler(client, peer_addr, fn peer, data ->
      send receiver, {:peer_data, ref, peer, data}
    end)
    result =
      receive do
        {:peer_data, ^ref, peer, data} ->
          {:ok, peer, data}
      after
        timeout ->
          {:error, :timeout}
      end
    remove_handler(client, handler_ref)
    result
  end

  @doc """
  Installs data handler which sends data received from peer
  to the given PID

  Data is sent in the format

      {:peer_data, peer, data}

  where `data` is a `binary` and `peer` has a format of `address` type.

  Returns a reference which may be used to cancel the handler
  using `remove_handler/2`.

  Note: when `recv/3` is called by the process which data is streamed to,
  data returned from `recv/3` will also be present in process mailbox.
  This is happening because `recv/3` installs regular data handler
  and does not remove handlers already installed in the client process.
  """
  @spec stream_to(t, to :: pid, peer_addr :: ip) :: reference
  def stream_to(client, to, peer_addr) do
    install_handler(client, peer_addr, fn peer, data ->
      send to, {:peer_data, peer, data}
    end)
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

  @spec maybe_retry(t, term) :: {:error, error} | term
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
