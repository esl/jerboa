defmodule Jerboa.Client.Relay.Channels do
  @moduledoc false

  alias Jerboa.Client
  alias Jerboa.Client.Relay.Channel
  alias Jerboa.Format

  defstruct locked_peers: MapSet.new(), locked_numbers: MapSet.new(),
    by_peer: %{}, by_number: %{}

  @type t :: %__MODULE__{
    locked_peers: MapSet.t(peer :: Client.address),
    locked_numbers: MapSet.t(Format.channel_number),
    by_peer: %{peer :: Client.address => Channel.t},
    by_number: %{Format.channel_number  => Channel.t}
  }
end
