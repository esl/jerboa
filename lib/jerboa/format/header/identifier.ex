defmodule Jerboa.Format.Header.Identifier do
  @moduledoc false

  alias Jerboa.Params

  def encode(%Params{identifier: x}) when is_binary(x) and 96 === bit_size(x) do
    x
  end
end
