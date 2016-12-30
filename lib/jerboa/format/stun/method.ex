defmodule Jerboa.Format.STUN.Method do
  @moduledoc """
  Encoders and decoder of STUN protocol methods
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


  # Returns name of a method
  @doc false
  @callback name() :: name

  # Returns code of a method
  @doc false
  @callback code() :: code

  # Returns list of classes compatible with a method
  @doc false
  @callback classes :: [Class.t, ...]
end
