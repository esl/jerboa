defmodule Jerboa.Client do
  @moduledoc """
  STUN client
  """

  alias Jerboa.Client

  def start do
    Supervisor.start_child(Client.Supervisor, [])
  end

  def bind(client, address: x, port: y) do
    GenServer.call(client, {:bind, x, y})
  end

  def persist(client, address: x, port: y) do
    GenServer.call(client, {:persist, x, y}, 2 * timeout())
  end

  def stop(client) do
    Supervisor.terminate_child(Client.Supervisor, client)
  end

  def timeout do
    Keyword.fetch!(Application.fetch_env!(:jerboa, :client), :timeout)
  end
end
