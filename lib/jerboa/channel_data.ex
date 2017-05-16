defmodule Jerboa.ChannelData do
  @moduledoc """
  Data structure representing data sent over TURN channel
  """

  defstruct [:channel_number, :data]

  @typedoc """
  The main data structure representing data sent over TURN channel

  * `:number` is a number of channel which data came from
  * `:data` is a raw binary data
  """
  @type t :: %__MODULE__{
    channel_number: Jerboa.Format.channel_number,
    data: binary
  }
end
