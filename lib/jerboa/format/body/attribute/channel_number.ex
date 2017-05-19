defmodule Jerboa.Format.Body.Attribute.ChannelNumber do
  @moduledoc """
  CHANNEL-NUMBER attribute as defined in [TURN RFC](https://trac.tools.ietf.org/html/rfc5766#section-14.1)
  """

  alias Jerboa.Format.ChannelNumber.First2BitsError
  alias Jerboa.Format.Body.Attribute.{Decoder, Encoder}
  alias Jerboa.Format.Meta

  @min_number 0x4000
  @max_number 0x7FFF

  defstruct [:number]

  @typedoc """
  Contains the number of the channel
  """
  @type t :: %__MODULE__{
    number: Jerboa.Format.channel_number
  }

  defimpl Encoder do
    alias Jerboa.Format.Body.Attribute.ChannelNumber
    @type_code 0x000C

    @spec type_code(ChannelNumber.t) :: integer
    def type_code(_), do: @type_code

    @spec encode(ChannelNumber.t, Meta.t) :: {Meta.t, binary}
    def encode(attr, meta), do: {meta, ChannelNumber.encode(attr)}
  end

  defimpl Decoder do
    alias Jerboa.Format.Body.Attribute.ChannelNumber

    @spec decode(ChannelNumber.t, value :: binary, meta :: Meta.t)
      :: {:ok, Meta.t, ChannelNumber.t} | {:error, struct}
    def decode(_, value, meta), do: ChannelNumber.decode(value, meta)
  end

  @doc false
  @spec encode(t) :: binary
  def encode(%__MODULE__{number: n}) when is_integer(n) and (n in @min_number..@max_number) do
    reserved = 0
    <<n :: size(16), reserved :: size(16)>>
  end

  @doc false
  @spec decode(binary, Meta.t) :: {:ok, Meta.t, t} | {:error, struct}
  def decode(<<number :: size(16)-bits, _reserved :: size(16)>>, meta) do
    case number do
      <<0b01 :: size(2), _ :: size(14)>> ->
        <<as_integer :: size(16)>> = number
        {:ok, meta, %__MODULE__{number: as_integer}}
      <<b :: 2-bits, _ :: 14>> ->
        {:error, First2BitsError.exception(bits: b)}
    end
  end

  @doc false
  def min_number, do: @min_number

  @doc false
  def max_number, do: @max_number

end
