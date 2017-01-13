defmodule Jerboa.Format.Body.Attribute do
  @moduledoc """
  STUN protocol attributes
  """
  alias Jerboa.Format.Body.Attribute

  defstruct [:name, :value]
  @typedoc """
  The data structure representing a STUN attribute
  """
  @type t :: %__MODULE__{
    name: module,
    value: struct
  }

  defmodule ComprehensionRequiredError do
    defexception [:message, :attribute]

    def message(%__MODULE__{attribute: n}) do
      "can not encode/decode comprehension required attribute #{n}"
    end
  end

  @doc false
  @spec decode(params :: Jerboa.Format.t, type :: non_neg_integer, value :: binary)
    :: {:ok, t} | {:error, struct}
  def decode(params, 0x0020, v) do
    Attribute.XORMappedAddress.decode params, v
  end
  def decode(_, x, _) when x in 0x0000..0x7FFF do
    {:error, ComprehensionRequiredError.exception(attribute: x)}
  end
end
