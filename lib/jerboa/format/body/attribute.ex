defmodule Jerboa.Format.Body.Attribute do
  @moduledoc """

  Encode and decode attributes for the STUN wire format.

  """
  alias Jerboa.Format.Body.Attribute

  defstruct [:name, :value]

  defmodule ComprehensionRequiredError do
    defexception [:message, :attribute]

    def message(%__MODULE__{attribute: n}) do
      "can not encode/decode comprehension required attribute #{n}"
    end
  end

  def decode(params, 0x0020, v) do
    Attribute.XORMappedAddress.decode params, v
  end
  def decode(_, x, _) when x in 0x0000..0x7FFF do
    {:error, ComprehensionRequiredError.exception(attribute: x)}
  end
end
