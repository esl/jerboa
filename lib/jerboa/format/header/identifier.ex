defmodule Jerboa.Format.Header.Identifier do
  @moduledoc false

  alias Jerboa.Params
  alias Jerboa.Format.Meta

  @bit_size 96

  @spec encode(Meta.t) :: binary
  def encode(%Meta{params: %Params{identifier: x}})
    when is_binary(x) and bit_size(x) === @bit_size do
    x
  end
end
