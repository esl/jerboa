defmodule Jerboa.Format.Body.Attribute do
  @moduledoc """
  STUN protocol attributes
  """

  alias Jerboa.Format.ComprehensionError
  alias Jerboa.Format.Body.Attribute.{XORMappedAddress, Lifetime, Data, Nonce,
                                      Username, Realm, ErrorCode,
                                      XORRelayedAddress, XORPeerAddress,
                                      RequestedTransport, DontFragment}
  alias Jerboa.Format.Meta

  defprotocol Encoder do
    @moduledoc false

    @spec encode(t, Meta.t) :: {Meta.t, binary}
    def encode(attr, meta)
  end

  defprotocol Decoder do
    @moduledoc false

    @spec decode(type :: t, value :: binary, meta :: Meta.t)
      :: {:ok, Meta.t, t} | {:error, struct}
    def decode(type, value, meta)
  end

  @internal_attrs [{XORMappedAddress, 0x0020}, {Lifetime, 0x000D}, {Data, 0x0013},
                   {Nonce, 0x0015}, {Username, 0x0006}, {Realm, 0x0014},
                   {ErrorCode, 0x0009}, {XORRelayedAddress, 0x0016},
                   {XORPeerAddress, 0x0012}, {RequestedTransport, 0x0019},
                   {DontFragment, 0x001A}]

  @external_attrs Application.get_env(:jerboa, Attributes, [])

  @attrs @internal_attrs ++ @external_attrs

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
    {meta, encode_(type(attr), value)}
  end

  @doc false
  @spec decode(Meta.t, type :: non_neg_integer, value :: binary)
    :: {:ok, Meta.t, t} | {:error, struct} | {:ignore, Meta.t}
  for {attr_mod, type_code} <- @attrs do
    def decode(meta, unquote(type_code), value) do
      Decoder.decode(struct(unquote(attr_mod)), value, meta)
    end
  end
  def decode(_, type, _) when type in 0x0000..0x7FFF do
    {:error, ComprehensionError.exception(attribute: type)}
  end
  def decode(meta, _, _), do: {:ignore, meta}

  defp type(attr) do
    @attrs[name(attr)] || raise "Cannot find type code for the attribute "
  end

  defp encode_(type, value) when byte_size(value) < @biggest_16 do
    <<type::16, byte_size(value)::16, value::binary>>
  end

end
