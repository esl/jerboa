defmodule Jerboa.Format.Body.Attribute.ReservationToken do
  @moduledoc """
  RESERVATION-TOKEN attribute as defined in
  [TURN RFC](https://trac.tools.ietf.org/html/rfc5766#section-14.9)
  """

  alias Jerboa.Format.Body.Attribute.{Decoder, Encoder}
  alias Jerboa.Format.ReservationToken.LengthError
  alias Jerboa.Format.Meta

  defstruct value: ""

  @byte_length 8

  @typedoc """
  Represents reservation token attribute value
  """
  @type t :: %__MODULE__{
    value: binary
  }

  defimpl Encoder do
    alias Jerboa.Format.Body.Attribute.ReservationToken
    @type_code 0x0022

    @spec type_code(ReservationToken.t) :: integer
    def type_code(_), do: @type_code

    @spec encode(ReservationToken.t, Meta.t) :: {Meta.t, binary}
    def encode(attr, meta), do: {meta, ReservationToken.encode(attr)}
  end

  defimpl Decoder do
    alias Jerboa.Format.Body.Attribute.ReservationToken

    @spec decode(ReservationToken.t, value :: binary, Meta.t)
      :: {:ok, Meta.t, ReservationToken.t} | {:error, struct}
    def decode(_, value, meta), do: ReservationToken.decode(value, meta)
  end

  @doc false
  @spec encode(t) :: binary
  def encode(%__MODULE__{value: v})
    when is_binary(v) and byte_size(v) == @byte_length, do: v

  @doc false
  @spec decode(binary, Meta.t) :: {:ok, Meta.t, t} | {:error, struct}
  def decode(value, meta) when byte_size(value) == @byte_length do
    {:ok, meta, %__MODULE__{value: value}}
  end
  def decode(value, _) do
    {:error, LengthError.exception(length: byte_size(value))}
  end
end
