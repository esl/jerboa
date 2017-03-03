defmodule Jerboa.Format.Body.Attribute.Lifetime do
  @moduledoc """
  LIFETIME attribute as defined in [TURN RFC](https://trac.tools.ietf.org/html/rfc5766#section-14.2)
  """

  alias Jerboa.Format.Body.Attribute.{Decoder,Encoder}
  alias Jerboa.Format.Lifetime.LengthError
  alias Jerboa.Params

  defstruct duration: 0

  @max_duration 2 |> :math.pow(32) |> :erlang.trunc() |> Kernel.-(1)

  @typedoc """
  Represents a lifetime of the allocation

  * `:duration` is a duration of a lifetime in seconds
  """
  @type t :: %__MODULE__{
    duration: non_neg_integer
  }

  defimpl Encoder do
    alias Jerboa.Format.Body.Attribute.Lifetime
    @type_code 0x000D

    @spec type_code(Lifetime.t) :: integer
    def type_code(_), do: @type_code

    @spec encode(Lifetime.t, Params.t) :: binary
    def encode(attr, _), do: Lifetime.encode(attr)
  end

  defimpl Decoder do
    alias Jerboa.Format.Body.Attribute.Lifetime

    @spec decode(Lifetime.t, value :: binary, params :: Params.t)
      :: {:ok, Lifetime.t} | {:error, struct}
    def decode(_, value, _), do: Lifetime.decode(value)
  end

  @doc false
  @spec encode(t) :: binary
  def encode(%__MODULE__{duration: duration})
    when is_integer(duration) and (duration in 0..@max_duration) do
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

  @doc false
  def max_duration, do: @max_duration
end