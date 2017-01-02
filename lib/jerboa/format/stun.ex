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
end
