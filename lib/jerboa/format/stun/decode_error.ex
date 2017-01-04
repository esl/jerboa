defmodule Jerboa.Format.STUN.DecodeError do
  @moduledoc """
  Data structure containing information about decoding failure
  """

  defstruct [format: ""]

  @typedoc """
  `DecodeError` struct

  * `format` - errors of STUN binary format, such as invalid cookie,
    invalid packet length etc.
  """
  @type t :: %__MODULE__{
    format: String.t
  }
end
