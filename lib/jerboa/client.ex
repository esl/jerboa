defmodule Jerboa.Client do
  @moduledoc """
  STUN client
  """

  alias Jerboa.Client

  @spec start(Keyword.t) :: Supervisor.on_start_child
  def start(x) do
    Supervisor.start_child(Client.Supervisor, [server(x)])
  end

  @spec bind(GenServer.server) :: {:inet.ip_address, :inet.port_number}
  def bind(client) do
    GenServer.call(client, :bind)
  end

  @spec persist(GenServer.server) :: :ok
  def persist(client) do
    GenServer.call(client, :persist, 2 * timeout())
  end

  @spec stop(GenServer.server) :: :ok |
  {:error, error} when error: :not_found |
  :simple_one_for_one
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
