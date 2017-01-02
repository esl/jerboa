defmodule Jerboa.Format.STUN.DecodeError do
  @moduledoc """
  Data structure containing information about decoding failure
  """

  defstruct [format: "", method: ""]

  @typedoc """
  `DecodeError` struct

  * `format` - errors of STUN binary format, such as invalid cookie,
    invalid packet length etc.
  * `method` - errors of STUN method (method unknown or incompatible
     with message class)
  """
  @type t :: %__MODULE__{
    format: String.t,
    method: String.t
  }

  @spec empty?(t) :: boolean
  def empty?(errors) do
    errors === %__MODULE__{}
  end
end
