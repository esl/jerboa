defmodule Jerboa.Client.Relay do
  @moduledoc false
  ## Data structure describing relay (allocation)

  alias Jerboa.Client
  alias Jerboa.Client.Relay.Permission

  defstruct [:address, :lifetime, :timer_ref, permissions: []]

  @type permission :: {peer_addr :: Client.address, timer_ref :: reference}
  @type t :: %__MODULE__{
    address: Client.address,
    lifetime: non_neg_integer,
    permissions: [Permission.t],
    timer_ref: reference
  }
end
