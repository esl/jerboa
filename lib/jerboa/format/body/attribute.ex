defmodule Jerboa.Format.Body.Attribute do
  @moduledoc """

  Encode and decode attributes for the STUN wire format.

  """
  alias Jerboa.Format.Body.Attribute

  defstruct [:name, :value]

  def decode(0x0001, v), do: Attribute.MappedAddress.decode v
  def decode(0x0020, v), do: Attribute.XORMappedAddress.decode v
end
