defmodule Jerboa.Format.Body.Attribute.Lifetime do
  @moduledoc """
  LIFETIME attribute as defined in [TURN RFC](https://trac.tools.ietf.org/html/rfc5766#section-14.2)
  """

  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Format.Lifetime.LengthError

  defstruct duration: 0

  @max_duration :math.pow(2, 32) - 1

  @typedoc """
  Represents a lifetime of the allocation

  * `:duration` is a duration of a lifetime in seconds
  """
  @type t :: %__MODULE__{
    duration: non_neg_integer
  }

  @doc false
  @spec encode(t) :: binary
  def encode(%__MODULE__{duration: duration})
    when is_integer(duration) and duration <= @max_duration and duration >= 0 do
    <<duration::32>>
  end

  @doc false
  @spec decode(value :: binary) :: {:ok, Attribute.t} | {:error, struct}
  def decode(<<duration::32>>) do
    {:ok, %__MODULE__{duration: duration}}
  end
  def decode(value) do
    {:error, LengthError.exception(length: byte_size(value))}
  end
end
