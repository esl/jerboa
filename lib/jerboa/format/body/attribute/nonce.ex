defmodule Jerboa.Format.Body.Attribute.Nonce do
  @moduledoc """
  NONCE attribute as defined in [STUN RFC](https://tools.ietf.org/html/rfc5389#section-15.8)
  """

  alias Jerboa.Format.Body.Attribute.{Decoder,Encoder}
  alias Jerboa.Params

  defstruct value: ""

  @typedoc """
  Represent nonce's value
  """
  @type t :: %__MODULE__{
    value: binary
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
  def encode(%__MODULE__{value: value}) when is_binary(value), do: value

  @doc false
  def decode(value), do: {:ok, %__MODULE__{value: value}}
end
