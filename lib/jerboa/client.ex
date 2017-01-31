defmodule Jerboa.Client do
  @moduledoc """
  STUN client
  """

  alias Jerboa.Client

  @spec start :: Supervisor.on_start_child
  def start do
    Supervisor.start_child(Client.Supervisor, [])
  end

  @spec bind(GenServer.server, Keyword.t) :: {:inet.ip_address, :inet.port_number}
  def bind(client, address: x, port: y) do
    GenServer.call(client, {:bind, x, y})
  end

  @spec persist(GenServer.server, Keyword.t) :: :ok
  def persist(client, address: x, port: y) do
    GenServer.call(client, {:persist, x, y}, 2 * timeout())
  end

  @spec stop(GenServer.server) :: :ok |
  {:error, error} when error: :not_found |
  :simple_one_for_one
  def stop(client) do
    Supervisor.terminate_child(Client.Supervisor, client)
  end

  @spec timeout :: non_neg_integer
  def timeout do
    Keyword.fetch!(Application.fetch_env!(:jerboa, :client), :timeout)
  end
end
