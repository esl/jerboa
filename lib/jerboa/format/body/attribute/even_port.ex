defmodule Jerboa.Format.Body.Attribute.EvenPort do
  @moduledoc """
  EVEN-PORT attribute as defined in [TURN RFC](https://trac.tools.ietf.org/html/rfc5766#section-14.6)
  """

  alias Jerboa.Format.Body.Attribute.{Encoder, Decoder}
  alias Jerboa.Format.EvenPort.FormatError
  alias Jerboa.Format.Meta

  defstruct reserved?: false

  @typedoc """
  Represents EVEN-PORT attribute

  `:reserved?` field indicates if R bit of attribute is
  set to 0 (`false`) or 1 (`true`).
  """
  @type t :: %__MODULE__{
    reserved?: boolean
  }

  defimpl Encoder do
    alias Jerboa.Format.Body.Attribute.EvenPort
    @type_code 0x0018

    @spec type_code(EvenPort.t) :: integer
    def type_code(_), do: @type_code

    @spec encode(EvenPort.t, Meta.t) :: {Meta.t, binary}
    def encode(attr, meta), do: {meta, EvenPort.encode(attr)}
  end

  defimpl Decoder do
    alias Jerboa.Format.Body.Attribute.EvenPort

    @spec decode(EvenPort.t, value :: binary, Meta.t)
      :: {:ok, Meta.t, EvenPort.t} | {:error, struct}
    def decode(_, value, meta), do: EvenPort.decode(value, meta)
  end

  @doc false
  @spec encode(t) :: binary
  def encode(%__MODULE__{reserved?: true}) do
    encode_bit(1)
  end
  def encode(%__MODULE__{reserved?: false}) do
    encode_bit(0)
  end

  @spec encode_bit(0 | 1) :: binary
  defp encode_bit(bit), do: <<bit::1, 0::7>>

  @doc false
  @spec decode(binary, Meta.t) :: {:ok, Meta.t, t} | {:error, struct}
  def decode(<<r_bit::1, 0::7>>, meta) do
    reserved? = if r_bit == 1, do: true, else: false
    {:ok, meta, %__MODULE__{reserved?: reserved?}}
  end
  def decode(_, _) do
    {:error, FormatError.exception()}
  end
end
