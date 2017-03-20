defmodule Jerboa.Format.Body.Attribute do
  @moduledoc """
  STUN protocol attributes
  """

  alias Jerboa.Format.ComprehensionError
  alias Jerboa.Format.Body.Attribute.{XORMappedAddress, Lifetime, Data, Nonce,
                                      Username, Realm, ErrorCode,
                                      XORRelayedAddress, XORPeerAddress,
                                      RequestedTransport}
  alias Jerboa.Format.Meta

  defprotocol Encoder do
    @moduledoc false

    @spec type_code(t) :: integer
    def type_code(attr)

    @spec encode(t, Meta.t) :: {Meta.t, binary}
    def encode(attr, meta)
  end

  defprotocol Decoder do
    @moduledoc false

    @spec decode(type :: t, value :: binary, meta :: Meta.t)
      :: {:ok, Meta.t, t} | {:error, struct}
    def decode(type, value, meta)
  end

  @known_attrs [XORMappedAddress, Lifetime, Data, Nonce, Username, Realm,
                ErrorCode, XORRelayedAddress, XORPeerAddress,
                RequestedTransport]

  @biggest_16 65_535

  @type t :: struct

  @doc """
  Retrieves attribute name from attribute struct
  """
  @spec name(t) :: module
  def name(%{__struct__: name}), do: name

  @doc false
  @spec encode(Meta.t, struct) :: binary
  def encode(meta, attr) do
    {meta, value} = Encoder.encode(attr, meta)
    type = Encoder.type_code(attr)
    {meta, encode_(type, value)}
  end

  @doc false
  @spec decode(Meta.t, type :: non_neg_integer, value :: binary)
    :: {:ok, Meta.t, t} | {:error, struct} | {:ignore, Meta.t}
  for attr <- @known_attrs do
    type = Encoder.type_code(struct(attr))
    def decode(meta, unquote(type), value) do
      Decoder.decode(struct(unquote(attr)), value, meta)
    end
  end
  def decode(_, type, _) when type in 0x0000..0x7FFF do
    {:error, ComprehensionError.exception(attribute: type)}
  end
  def decode(meta, _, _), do: {:ignore, meta}

  defp encode_(type, value) when byte_size(value) < @biggest_16 do
    <<type::16, byte_size(value)::16, value::binary>>
  end
end
