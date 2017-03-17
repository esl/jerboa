defmodule Jerboa.Client do
  @moduledoc """
  STUN client process

  Use `start/1` function to spawn new client process:

      iex> Jerboa.Client.start server: %{address: server_ip, port: server_port}
      {:ok, #PID<...>}

  (see `start/1` for configuration options)

  Currently the only implemented STUN method is [Binding](), which allows a client to
  query the server for its external IP address and port. To achieve that, this module
  provides `bind/1` and `persist/1` functions.

  The `bind/1` issues a Binding request to a server and returns reflexive IP address and port.
  If returned message is not a valid STUN message or it doesn't include XOR Mapped Address
  attribute, the client simply crashes.

      iex> Jerboa.Client.bind client_pid
      {{192, 168, 1, 20}, 32780}

  `persist/1` sends a Binding indication to a server, which is not meant to return
  any response, but is an attempt to refresh NAT bindings in routers on the path to a server.
  Note that this is only an attempt, there is no guarantee that some router on the path
  won't rebind client's inside address and port.
  """

  @type t :: pid
  @type port_no :: :inet.port_number
  @type ip :: :inet.ip_address

  alias Jerboa.Client

  @doc """
  Starts STUN client process

      iex> Jerboa.Client.start server: %{address: {192, 168, 1, 20}, port: 3478}
      {:ok, #PID<...>}

  ### Options

  * `server` - required - a map with `:address` and `:port` keys
  """
  @spec start(options :: Keyword.t) :: Supervisor.on_start_child
  def start(x) do
    Supervisor.start_child(Client.Supervisor, [server(x)])
  end

  @doc """
  Sends Binding request to a server

  Returns reflexive address and port on successful response. Otherwise the
  client process crashes.
  """
  @spec bind(t) :: {ip, port_no} | no_return
  def bind(client) do
    GenServer.call(client, :bind, 2 * timeout())
  end

  @doc """
  Sends Binding indication to a server
  """
  @spec persist(t) :: :ok
  def persist(client) do
    GenServer.cast(client, :persist)
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

  defp server(server: %{address: a, port: p}) do
    [address: a, port: p]
  end

  @spec timeout :: non_neg_integer
  defp timeout do
    Keyword.fetch!(Application.fetch_env!(:jerboa, :client), :timeout)
  end
end
