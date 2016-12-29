defmodule Jerboa.Format.STUN do
  @moduledoc """
  Utility functions related to STUN messages
  """

  @type class :: :request
               | :indication
               | :success
               | :error

  @type integer_class :: 0 | 1 | 2 | 3

  @doc """
  Returns value of STUN magic cookie
  """
  @spec magic :: 554_869_826
  def magic, do: 554_869_826

  @doc """
  Converts integer to atom representing STUN class
  """
  @spec class_from_integer(integer_class) :: class
  def class_from_integer(0), do: :request
  def class_from_integer(1), do: :indication
  def class_from_integer(2), do: :success
  def class_from_integer(3), do: :error

  @doc """
  Converts atom to integer representing STUN class
  """
  @spec class_to_integer(class) :: integer_class
  def class_to_integer(:request), do: 0
  def class_to_integer(:indication), do: 1
  def class_to_integer(:success), do: 2
  def class_to_integer(:error), do: 3

end
