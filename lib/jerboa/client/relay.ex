defmodule Jerboa.Client.Relay do
  @moduledoc false
  ## Data structure describing relay (allocation)

  alias Jerboa.Client
  alias Jerboa.Client.Relay.Permission

  defstruct [:address, :lifetime, :timer_ref, permissions: []]

  @type permission :: {peer_addr :: Client.address, timer_ref :: reference}
  @type t :: %__MODULE__{
    address:   nil | Client.address,
    lifetime:  nil | non_neg_integer,
    timer_ref: nil | reference,
    permissions: [Permission.t]
  }
end
