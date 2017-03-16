defmodule Jerboa.Format.Header.Identifier do
  @moduledoc false

  alias Jerboa.Params
  alias Jerboa.Format.Meta

  @spec encode(Meta.t) :: binary
  def encode(%Meta{params: %Params{identifier: x}})
    when is_binary(x) and 96 === bit_size(x) do
    x
  end
end
