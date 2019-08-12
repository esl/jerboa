defmodule Jerboa.Format.Body.Attribute.Bandwidth do
  @moduledoc """
  Bandwidth attribute as defined in [TURN RFC](https://trac.tools.ietf.org/html/rfc5766#section-14.2)
  """

  alias Jerboa.Format.Body.Attribute.{Decoder,Encoder}
  alias Jerboa.Format.Lifetime.LengthError
  alias Jerboa.Format.Meta

  defstruct value: 0

  @max_value 2 |> :math.pow(32) |> :erlang.trunc() |> Kernel.-(1)

  @typedoc """
  Represents a lifetime of the allocation

  * `:value` is a value of a lifetime in seconds
  """
  @type t :: %__MODULE__{
    value: non_neg_integer
  }

  defimpl Encoder do
    alias Jerboa.Format.Body.Attribute.Bandwidth
    @type_code 0x0010

    @spec type_code(Bandwidth.t) :: integer
    def type_code(_), do: @type_code

    @spec encode(Bandwidth.t, Meta.t) :: {Meta.t, binary}
    def encode(attr, meta), do: {meta, Bandwidth.encode(attr)}
  end

  defimpl Decoder do
    alias Jerboa.Format.Body.Attribute.Bandwidth

    @spec decode(Bandwidth.t, value :: binary, meta :: Meta.t)
      :: {:ok, Meta.t, Bandwidth.t} | {:error, struct}
    def decode(_, value, meta), do: Bandwidth.decode(value, meta)
  end

  @doc false
  @spec encode(t) :: binary
  def encode(%__MODULE__{value: value})
    when is_integer(value) and (value in 0..@max_value) do
    <<value::32>>
  end

  @doc false
  def decode(<<value::32>>, meta) do
    {:ok, meta, %__MODULE__{value: value}}
  end
  def decode(value, _) do
    {:error, LengthError.exception(length: byte_size(value))}
  end

  @doc false
  def max_value, do: @max_value
end
