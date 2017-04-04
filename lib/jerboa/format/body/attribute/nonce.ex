defmodule Jerboa.Format.Body.Attribute.Nonce do
  @moduledoc """
  NONCE attribute as defined in [STUN RFC](https://tools.ietf.org/html/rfc5389#section-15.8)
  """

  alias Jerboa.Format.Body.Attribute.{Decoder,Encoder}
  alias Jerboa.Format.Nonce.LengthError
  alias Jerboa.Format.Meta

  defstruct value: ""

  @max_chars 128

  @typedoc """
  Represent nonce's value
  """
  @type t :: %__MODULE__{
    value: String.t
  }

  defimpl Encoder do
    alias Jerboa.Format.Body.Attribute.Nonce

    @spec encode(Nonce.t, Meta.t) :: {Meta.t, binary}
    def encode(attr, meta), do: {meta, Nonce.encode(attr)}
  end

  defimpl Decoder do
    alias Jerboa.Format.Body.Attribute.Nonce

    @spec decode(Nonce.t, value :: binary, meta :: Meta.t)
      :: {:ok, Meta.t, Nonce.t} | {:error, struct}
    def decode(_, value, meta), do: Nonce.decode(value, meta)
  end

  @doc false
  def encode(%__MODULE__{value: value}) do
    if String.valid?(value) && String.length(value) <= @max_chars do
      value
    else
      raise ArgumentError
    end
  end

  @doc false
  def decode(value, meta) do
    length = String.length(value)
    if String.valid?(value) && length <= @max_chars do
      {:ok, meta, %__MODULE__{value: value}}
    else
      {:error, LengthError.exception(length: length)}
    end
  end

  @doc false
  def max_chars, do: @max_chars
end
