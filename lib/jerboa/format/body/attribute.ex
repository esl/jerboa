defmodule Jerboa.Format.Body.Attribute do
  @moduledoc """
  STUN protocol attributes
  """
  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Format.ComprehensionError

  defstruct [:name, :value]
  @typedoc """
  The data structure representing a STUN attribute
  """
  @type t :: %__MODULE__{
    name: module,
    value: struct
  }

  @doc false
  @spec encode(Jerboa.Format.t, struct) :: binary
  def encode(p, a = %Attribute.XORMappedAddress{}) do
    encode_(0x0020, Attribute.XORMappedAddress.encode(p, a))
  end

  @doc false
  @spec decode(params :: Jerboa.Format.t, type :: non_neg_integer, value :: binary)
    :: {:ok, t} | {:error, struct} | :ignore
  def decode(params, 0x0020, v) do
    Attribute.XORMappedAddress.decode params, v
  end
  def decode(_, x, _) when x in 0x0000..0x7FFF do
    {:error, ComprehensionError.exception(attribute: x)}
  end
  def decode(_, _, _) do
    :ignore
  end

  defp encode_(type, value) do
    <<type::16, byte_size(value)::16, value::binary>>
  end
end
