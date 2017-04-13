defmodule Jerboa.Client.Relay.Permission do
  @moduledoc false

  alias Jerboa.Client

  defstruct [:peer_address, :timer_ref, :transaction_id, acked?: false]

  @type t :: %__MODULE__{
    peer_address: Client.ip,
    timer_ref: reference,
    transaction_id: binary,
    acked?: boolean
  }
end
