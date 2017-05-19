defmodule Jerboa.Client.Relay do
  @moduledoc false
  ## Data structure describing relay (allocation)

  alias Jerboa.Client
  alias Jerboa.Client.Channel
  alias Jerboa.Format

  defstruct [:address, :lifetime, :timer_ref, permissions: %{},
             channels: {%{}, %{}}]

  @type t :: %__MODULE__{
    address:   nil | Client.address,
    lifetime:  nil | non_neg_integer,
    timer_ref: nil | reference,
    permissions: %{Client.ip => timer_ref :: reference},

    ## `:channels` is a tuple of two maps, which have the same values,
    ## but under different keys. The first one's keys are peer adresses
    ## bound to channels, the other one's keys are channel numbers of
    ## those channels. The values in both are Channel structs.
    channels: {%{peer :: Client.address => Channel.t},
               %{Format.channel_number  => Channel.t}}
  }
end
