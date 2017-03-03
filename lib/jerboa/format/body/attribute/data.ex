defmodule Jerboa.Format.Body.Attribute.Data do
  @moduledoc """
  DATA attribute as defined in [TURN RFC](https://trac.tools.ietf.org/html/rfc5766#section-14.4)
  """

  alias Jerboa.Format.Body.Attribute.{Decoder,Encoder}
  alias Jerboa.Params

  defstruct content: ""

  @typedoc """
  Represents data sent between client and its peer
  """
  @type t :: %__MODULE__{
    content: binary
  }

  defimpl Encoder do
    alias Jerboa.Format.Body.Attribute.Data
    @type_code 0x0013

    @spec type_code(Data.t) :: integer
    def type_code(_), do: @type_code

    @spec encode(Data.t, Params.t) :: binary
    def encode(attr, _), do: Data.encode(attr)
  end

  defimpl Decoder do
    alias Jerboa.Format.Body.Attribute.Data

    @spec decode(Data.t, value :: binary, params :: Params.t)
      :: {:ok, Data.t} | {:error, struct}
    def decode(_, value, _), do: Data.decode(value)
  end

  @doc false
  def encode(%__MODULE__{content: content}) when is_binary(content), do: content

  @doc false
  def decode(value), do: {:ok, %__MODULE__{content: value}}
end
