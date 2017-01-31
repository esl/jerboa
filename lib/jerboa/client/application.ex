defmodule Jerboa.Client.Application do
  @moduledoc false

  use Application

  def start(_, _) do
    Supervisor.start_link(children(), options())
  end

  defp children do
    import Supervisor.Spec, warn: false
    [supervisor(Jerboa.Client.Supervisor, [])]
  end

  defp options do
    [strategy: :one_for_one, name: Jerboa.Client.Application]
  end
end
