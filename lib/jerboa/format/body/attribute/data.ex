defmodule Jerboa.Format.Body.Attribute.Data do
  @moduledoc """
  DATA attribute as defined in [TURN RFC](https://trac.tools.ietf.org/html/rfc5766#section-14.4)
  """

  alias Jerboa.Format.Body.Attribute.{Decoder,Encoder}
  alias Jerboa.Format.Meta

  defstruct content: ""

  @typedoc """
  Represents data sent between client and its peer
  """
  @type t :: %__MODULE__{
    content: binary
  }

  defimpl Encoder do
    alias Jerboa.Format.Body.Attribute.Data

    @spec encode(Data.t, Meta.t) :: {Meta.t, binary}
    def encode(attr, meta), do: {meta, Data.encode(attr)}
  end

  defimpl Decoder do
    alias Jerboa.Format.Body.Attribute.Data

    @spec decode(Data.t, value :: binary, meta :: Meta.t)
      :: {:ok, Meta.t, Data.t} | {:error, struct}
    def decode(_, value, meta), do: Data.decode(value, meta)
  end

  @doc false
  def encode(%__MODULE__{content: content}) when is_binary(content), do: content

  @doc false
  def decode(value, meta), do: {:ok, meta, %__MODULE__{content: value}}
end
