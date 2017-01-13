defmodule Jerboa.Format.Head.Identifier do
  @moduledoc false

  def encode(%Jerboa.Format{identifier: x}) when is_binary(x) and 96 === bit_size(x) do
    x
  end
end
