defmodule Jerboa.Format.STUN.Method do
  @moduledoc """
  Encoder and decoder of STUN protocol methods

  Currently supported methods are:
  * Binding - `Jerboa.Format.STUN.Method.Binding`
  """

  alias Jerboa.Format.STUN.Class

  @typedoc """
  Human-readable name of a method
  """
  @type name :: atom

  @typedoc """
  Integer value of a method
  """
  @type code :: non_neg_integer

  @methods [__MODULE__.Binding]

  defmodule Behaviour do
    @moduledoc false

    alias Jerboa.Format.STUN.Method

    # Returns name of a method
    @doc false
    @callback name() :: Method.name

    # Returns code of a method
    @doc false
    @callback code() :: Method.code

    # Returns list of classes compatible with a method
    @doc false
    @callback classes :: [Class.t, ...]
  end

  @doc false
  @spec decode(name_or_code :: name | code) :: name | nil
  def decode(name_or_code)

  @doc false
  @spec class_allowed?(name, class :: Class.t) :: boolean
  def class_allowed?(name, class)

  for method <- @methods do
    name = method.name
    code = method.code
    classes = method.classes

    def decode(unquote(code)), do: unquote(name)
    def decode(unquote(name)), do: unquote(name)

    def class_allowed?(unquote(name), class) when class in unquote(classes), do: true
  end

  def decode(_), do: nil
  def class_allowed?(_, _), do: false
end
