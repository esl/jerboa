defmodule Jerboa.Format.Body.Attribute.RequestedTransport do
  @moduledoc """
  REQUESTED-TRANSPORT attribute as defined in the
  [TURN RFC](https://trac.tools.ietf.org/html/rfc5766#section-14.7)
  """

  alias Jerboa.Format.Body.Attribute.{Encoder, Decoder}
  alias Jerboa.Format.RequestedTransport.{ProtocolError,
                                          LengthError}
  alias Jerboa.Format.Meta

  defstruct protocol: :udp

  @type protocol :: :udp
  @type protocol_code :: 17

  @typedoc """
  Represents transport requested for allocation

  Currently only `:udp` is a valid value.
  """
  @type t :: %__MODULE__{
    protocol: protocol
  }

  defimpl Encoder do
    alias Jerboa.Format.Body.Attribute.RequestedTransport
    @type_code 0x0019

    @spec type_code(RequestedTransport.t) :: integer
    def type_code(_), do: @type_code

    @spec encode(RequestedTransport.t, Meta.t) :: {Meta.t, binary}
    def encode(attr, meta), do: {meta, RequestedTransport.encode(attr)}
  end

  defimpl Decoder do
    alias Jerboa.Format.Body.Attribute.RequestedTransport

    @spec decode(RequestedTransport.t, value :: binary, Meta.t)
      :: {:ok, Meta.t, RequestedTransport.t} | {:error, struct}
    def decode(_, value, meta), do: RequestedTransport.decode(value, meta)
  end

  @doc false
  def encode(%__MODULE__{protocol: proto}) do
    case proto_to_code(proto) do
      :error ->
        raise ArgumentError, "invalid protocol in REQUESTED-TRANSPORT attribute"
      proto_code ->
        <<proto_code::8, 0::24>>
    end
  end

  @doc false
  def decode(<<proto_code::8, _::24>>, meta) do
    case code_to_proto(proto_code) do
      :error ->
        {:error, ProtocolError.exception(protocol_code: proto_code)}
      proto ->
        {:ok, meta, %__MODULE__{protocol: proto}}
    end
  end
  def decode(value, _) do
    {:error, LengthError.exception(length: byte_size(value))}
  end

  defp code_to_proto(17), do: :udp
  defp code_to_proto(_), do: :error

  defp proto_to_code(:udp), do: 17
  defp proto_to_code(_), do: :error

  @doc false
  def known_protocol_codes, do: [17]

  @doc false
  def known_protocols, do: [:udp]
end
