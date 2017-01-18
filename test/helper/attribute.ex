defmodule Jerboa.Test.Helper.Attribute do
  @moduledoc false

  def total(x) do
    x |> Keyword.values |> Enum.sum
  end
end
