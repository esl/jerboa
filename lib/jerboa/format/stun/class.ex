defmodule Jerboa.Format.STUN.Class do
  @moduledoc """
  A STUN message class
  """

  @typedoc """
  Class of STUN message

  Note that `:error` here refers to STUN
  error response class, it is not an indication
  that this value is invalid.
  """
  @type t :: :request | :indication | :success | :error

  @typedoc """
  Integer representing STUN class, as encoded in STUN
  protocol packets
  """
  @type integer_t :: 0 | 1 | 2 | 3


  @doc """
  Converts integer to atom representing STUN class

  ## Examples

      iex> Jerboa.Format.STUN.Class.from_integer(0)
      :request
      iex> Jerboa.Format.STUN.Class.from_integer(3)
      :error # this is a valid STUN class
  """
  @spec from_integer(integer_t) :: t
  def from_integer(0), do: :request
  def from_integer(1), do: :indication
  def from_integer(2), do: :success
  def from_integer(3), do: :error

  @doc """
  Converts atom to integer representing STUN class

  ## Examples

      iex> Jerboa.Format.STUN.Class.to_integer(:indication)
      1
      iex> Jerboa.Format.STUN.Class.to_integer(:success)
      2
  """
  @spec to_integer(t) :: integer_t
  def to_integer(:request), do: 0
  def to_integer(:indication), do: 1
  def to_integer(:success), do: 2
  def to_integer(:error), do: 3
end
