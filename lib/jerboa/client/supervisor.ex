defmodule Jerboa.Client.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    supervise(children(), strategy: :simple_one_for_one)
  end

  defp children do
    import Supervisor.Spec, warn: false
    [worker(Jerboa.Client.Worker, [], restart: :transient)]
  end
end
