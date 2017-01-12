defmodule Jerboa.Format.Head.MagicCookie do
  @moduledoc """

  There's really nothing magical here. In a module with an `encode'
  like this for consistancy with other fields.

  """

  def encode, do: <<value()::32>>

  def value, do: 0x2112A442
end
