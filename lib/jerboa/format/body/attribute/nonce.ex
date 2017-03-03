defmodule Jerboa.Format.Body.Attribute.Nonce do
  @moduledoc """
  NONCE attribute as defined in [STUN RFC](https://tools.ietf.org/html/rfc5389#section-15.8)
  """

  alias Jerboa.Format.Body.Attribute.{Decoder,Encoder}
  alias Jerboa.Format.Nonce.LengthError
  alias Jerboa.Params

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
    @type_code 0x0015

    @spec type_code(Data.t) :: integer
    def type_code(_), do: @type_code

    @spec encode(Nonce.t, Params.t) :: binary
    def encode(attr, _), do: Nonce.encode(attr)
  end

  defimpl Decoder do
    alias Jerboa.Format.Body.Attribute.Nonce

    @spec decode(Nonce.t, value :: binary, params :: Params.t)
      :: {:ok, Nonce.t} | {:error, struct}
    def decode(_, value, _), do: Nonce.decode(value)
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
  def decode(value) do
    length = String.length(value)
    if String.valid?(value) && length <= @max_chars do
      {:ok, %__MODULE__{value: value}}
    else
      {:error, LengthError.exception(length: length)}
    end
  end

  @doc false
  def max_chars, do: @max_chars
end
