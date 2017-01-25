defmodule Jerboa.Test.Helper.Header do
  @moduledoc false

  def i do
    :crypto.strong_rand_bytes(div(96, 8))
  end
end
