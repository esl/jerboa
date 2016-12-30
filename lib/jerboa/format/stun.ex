defmodule Jerboa.Format.STUN do
  @moduledoc """
  Utility functions related to STUN messages
  """

  @doc """
  Returns value of STUN magic cookie
  """
  @spec magic :: 554_869_826
  def magic, do: 554_869_826

end
