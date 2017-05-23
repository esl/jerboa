defmodule Jerboa.Client.Relay do
  @moduledoc false
  ## Data structure describing relay (allocation)

  alias Jerboa.Client

  defstruct [:address, :lifetime, :timer_ref, permissions: %{}]

  @type t :: %__MODULE__{
    address:   nil | Client.address,
    lifetime:  nil | non_neg_integer,
    timer_ref: nil | reference,
    permissions: %{Client.ip => timer_ref :: reference}
  }
end
