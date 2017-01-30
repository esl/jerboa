defmodule Jerboa.Test.Helper.Header do
  @moduledoc false

  def first_2_bits(<<x::2-bits, _::bits>>) do
    x
  end

  def type(<<_::2, x::14, _::144>>) do
    x
  end

  def magic_cookie(<<_::32, x::32, _::96>>) do
    x
  end

  def identifier(<<_::64, x::96-bits>>) do
    x
  end

  def identifier do
    :crypto.strong_rand_bytes(div(96, 8))
  end
end
