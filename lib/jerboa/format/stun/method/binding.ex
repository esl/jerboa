defmodule Jerboa.Format.STUN.Method.Binding do
  @moduledoc """
  STUN Binding method

  Described in the [STUN RFC](https://tools.ietf.org/html/rfc5389#section-7)

  This method supports all STUN message classes.
  """

  @behaviour Jerboa.Format.STUN.Method.Behaviour

  @type name :: :binding
  @type code :: 1

  @doc false
  def name, do: :binding

  @doc false
  def code, do: 1

  @doc false
  def classes, do: [:request, :indication, :success, :error]
end
