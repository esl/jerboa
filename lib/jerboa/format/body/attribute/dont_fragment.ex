defmodule Jerboa.Format.Body.Attribute.DontFragment do
  @moduledoc """
  DONT-FRAGMENT attribute as defined in [TURN RFC](https://trac.tools.ietf.org/html/rfc5766#section-14.8)
  """

  alias Jerboa.Format.Body.Attribute.{Decoder,Encoder}
  alias Jerboa.Format.DontFragment.ValuePresentError
  alias Jerboa.Format.Meta

  defstruct []

  @typedoc """
  Represent DONT-FRAGMENT attribute

  This attribute doesn't have any value associated with it.
  """
  @type t :: %__MODULE__{}

  defimpl Encoder do
    alias Jerboa.Format.Body.Attribute.DontFragment

    @spec encode(DontFragment.t, Meta.t) :: {Meta.t, binary}
    def encode(_attr, meta), do: {meta, DontFragment.encode()}
  end

  defimpl Decoder do
    alias Jerboa.Format.Body.Attribute.DontFragment

    @spec decode(DontFragment.t, value :: binary, meta :: Meta.t)
      :: {:ok, Meta.t, DontFragment.t} | {:error, struct}
    def decode(_, value, meta), do: DontFragment.decode(value, meta)
  end

  @doc false
  @spec encode :: <<>>
  def encode, do: <<>>

  @doc false
  @spec decode(value :: binary, meta :: Meta.t) :: {:ok, t} | {:error, struct}
  def decode(<<>>, meta), do: {:ok, meta, %__MODULE__{}}
  def decode(_, _), do: {:error, ValuePresentError.exception()}
end
