defmodule Jerboa.Format.Body.Attribute.Lifetime do
  @moduledoc """
  LIFETIME attribute as defined in [TURN RFC](https://trac.tools.ietf.org/html/rfc5766#section-14.2)
  """

  alias Jerboa.Format.Body.Attribute.{Decoder,Encoder}
  alias Jerboa.Format.Lifetime.LengthError
  alias Jerboa.Format.Meta

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

    @spec encode(Lifetime.t, Meta.t) :: {Meta.t, binary}
    def encode(attr, meta), do: {meta, Lifetime.encode(attr)}
  end

  defimpl Decoder do
    alias Jerboa.Format.Body.Attribute.Lifetime

    @spec decode(Lifetime.t, value :: binary, meta :: Meta.t)
      :: {:ok, Meta.t, Lifetime.t} | {:error, struct}
    def decode(_, value, meta), do: Lifetime.decode(value, meta)
  end

  @doc false
  @spec encode(t) :: binary
  def encode(%__MODULE__{duration: duration})
    when is_integer(duration) and (duration in 0..@max_duration) do
    <<duration::32>>
  end

  @doc false
  def decode(<<duration::32>>, meta) do
    {:ok, meta, %__MODULE__{duration: duration}}
  end
  def decode(value, _) do
    {:error, LengthError.exception(length: byte_size(value))}
  end

  @doc false
  def max_duration, do: @max_duration
end
