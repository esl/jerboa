defmodule Jerboa.Format.Head.MagicCookie do
  def encode, do: <<0x2112A442::32>>
end
