defmodule Jerboa.Format.Body.Attribute do
  @moduledoc """
  STUN protocol attributes
  """

  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Format.ComprehensionError
  alias Jerboa.Params

  @biggest_16 65_535

  @type t :: struct

  @doc """
  Retrieves attribute name from attribute struct
  """
  @spec name(t) :: module
  def name(%{__struct__: name}), do: name

  @doc false
  @spec encode(Params.t, struct) :: binary
  def encode(params, attr = %Attribute.XORMappedAddress{}) do
    encode_(0x0020, Attribute.XORMappedAddress.encode(params, attr))
  end
  def encode(_params, attr = %Attribute.Lifetime{}) do
    encode_(0x000D, Attribute.Lifetime.encode(attr))
  end

  @doc false
  @spec decode(Params.t, type :: non_neg_integer, value :: binary)
    :: {:ok, t} | {:error, struct} | :ignore
  def decode(params, 0x0020, value) do
    Attribute.XORMappedAddress.decode params, value
  end
  def decode(_params, 0x000D, value) do
    Attribute.Lifetime.decode value
  end
  def decode(_, type, _) when type in 0x0000..0x7FFF do
    {:error, ComprehensionError.exception(attribute: type)}
  end
  def decode(_, _, _) do
    :ignore
  end

  defp encode_(type, value) when byte_size(value) < @biggest_16 do
    <<type::16, byte_size(value)::16, value::binary>>
  end
end
