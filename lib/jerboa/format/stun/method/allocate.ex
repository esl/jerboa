defmodule Jerboa.Format.STUN.Method.Allocate do
  @moduledoc """
  STUN Allocate method

  Described in the [TURN RFC](https://tools.ietf.org/html/rfc5766#section-2.2)

  This method support only request and response (both success and error)
  message classes.
  """

  @behaviour Jerboa.Format.STUN.Method.Behaviour

  @type name :: :allocate
  @type code :: 3

  @doc false
  def name, do: :allocate

  @doc false
  def code, do: 3

  @doc false
  def classes, do: [:request, :success, :error]
end
