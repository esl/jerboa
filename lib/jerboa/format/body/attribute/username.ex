defmodule Jerboa.Format.Body.Attribute.Username do
  @moduledoc """
  USERNAME attribute as defined in [STUN RFC](https://tools.ietf.org/html/rfc5389#section-15.3)
  """

  alias Jerboa.Format.Body.Attribute.{Decoder,Encoder}
  alias Jerboa.Format.Username.LengthError
  alias Jerboa.Format.Meta

  defstruct value: ""

  @max_length 512

  @typedoc """
  Represents username used for authentication and message-integrity
  checks
  """
  @type t :: %__MODULE__{
    value: binary
  }

  defimpl Encoder do
    alias Jerboa.Format.Body.Attribute.Username

    @spec encode(Username.t, Meta.t) :: {Meta.t, binary}
    def encode(attr, meta), do: {meta, Username.encode(attr)}
  end

  defimpl Decoder do
    alias Jerboa.Format.Body.Attribute.Username

    @spec decode(Username.t, value :: binary, meta :: Meta.t)
      :: {:ok, Username.t} | {:error, struct}
    def decode(_, value, meta), do: Username.decode(value, meta)
  end

  @doc false
  def encode(%__MODULE__{value: value})
    when is_binary(value) and byte_size(value) in 0..@max_length do
    if String.valid?(value) do
      value
    else
      raise ArgumentError
    end
  end
  def encode(_), do: raise ArgumentError

  @doc false
  def decode(value, meta) do
    length = byte_size(value)
    if String.valid?(value) && length <= @max_length do
      {:ok, meta, %__MODULE__{value: value}}
    else
      {:error, LengthError.exception(length: length)}
    end
  end

  @doc false
  def max_length, do: @max_length
end
