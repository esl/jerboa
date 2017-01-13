defmodule Jerboa.Format.Head.MagicCookie do
  @moduledoc false

  def encode, do: <<value()::32>>

  def value, do: 0x2112A442
end
