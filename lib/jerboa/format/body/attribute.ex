defmodule Jerboa.Format.Body.Attribute do
  @moduledoc """
  STUN protocol attributes
  """

  alias Jerboa.Format.ComprehensionError
  alias Jerboa.Params

  defprotocol EncoderProtocol do
    @spec type_code(t) :: integer
    def type_code(attr)

    @spec encode(t, Params.t) :: binary
    def encode(attr, params)
  end

  defprotocol DecoderProtocol do
    @spec decode(type :: t, value :: binary, params :: Params.t)
    :: {:ok, t} | {:error, struct} | :ignore
    def decode(type, value, params)
  end

  @apps_lib_dirs  [:code.lib_dir(:jerboa, :ebin)]
  @known_attrs Protocol.extract_impls(DecoderProtocol, @apps_lib_dirs)

  @biggest_16 65_535

  @type t :: struct


  @doc """
  Retrieves attribute name from attribute struct
  """
  @spec name(t) :: module
  def name(%{__struct__: name}), do: name

  @doc false
  @spec encode(Params.t, struct) :: binary
  def encode(params, attr) do
    encode_(EncoderProtocol.type_code(attr),
      EncoderProtocol.encode(attr, params))
  end
  def encode(_params, attr = %Attribute.Lifetime{}) do
    encode_(0x000D, Attribute.Lifetime.encode(attr))
  end

  @doc false
  @spec decode(Params.t, type :: non_neg_integer, value :: binary)
    :: {:ok, t} | {:error, struct} | :ignore
  for attr <- @known_attrs do
    type = EncoderProtocol.type_code(struct(attr))
    def decode(params, unquote(type), value) do
      DecoderProtocol.decode(struct(unquote(attr)), value, params)
    end
  end
  def decode(_params, 0x000D, value) do
    Attribute.Lifetime.decode value
  end
  def decode(_, type, _) when type in 0x0000..0x7FFF do
    {:error, ComprehensionError.exception(attribute: type)}
  end
  def decode(_, _, _), do: :ignore

  defp encode_(type, value) when byte_size(value) < @biggest_16 do
    <<type::16, byte_size(value)::16, value::binary>>
  end
end
