defmodule Jerboa.Client.Relay.Channel do
  @moduledoc false

  alias Jerboa.Client
  alias Jerboa.Format

  defstruct [:peer, :number, :timer_ref]

  @type t :: %__MODULE__{
    peer: Client.address,
    number: Format.channel_number,
    timer_ref: reference
  }
end
