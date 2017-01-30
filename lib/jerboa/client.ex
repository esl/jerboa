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

  def stop(client) do
    Supervisor.terminate_child(Client.Supervisor, client)
  end
end
