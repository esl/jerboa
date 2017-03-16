defmodule Jerboa.Format.Body.Attribute.Realm do
  @moduledoc """
  REALM attribute as defined in [STUN RFC](https://tools.ietf.org/html/rfc5389#section-15.7)
  """

  alias Jerboa.Format.Body.Attribute.{Decoder, Encoder}
  alias Jerboa.Format.Realm.LengthError
  alias Jerboa.Format.Meta

  defstruct value: ""

  @max_chars 128

  @typedoc """
  Represents realm value used for authentication
  """
  @type t :: %__MODULE__{
    value: String.t
  }

  defimpl Encoder do
    alias Jerboa.Format.Body.Attribute.Realm
    @type_code 0x0014

    @spec type_code(Realm.t) :: integer
    def type_code(_), do: @type_code

    @spec encode(Realm.t, Meta.t) :: {Meta.t, binary}
    def encode(attr, meta), do: {meta, Realm.encode(attr)}
  end

  defimpl Decoder do
    alias Jerboa.Format.Body.Attribute.Realm

    @spec decode(Realm.t, value :: binary, Meta.t)
      :: {:ok, Meta.t, Realm.t} | {:error, struct}
    def decode(_, value, meta), do: Realm.decode(value, meta)
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
