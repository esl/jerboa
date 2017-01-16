defmodule Jerboa.Format.BodyTest do
  use ExUnit.Case, async: true
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute

  describe "Body.Attribute.decode/1" do

    test "unknow comprehension required attribute results in :error tuple" do
      for x <- 0x0000..0x7FFF, not x in known() do
        assert {:error, %Format.ComprehensionError{attribute: x}} == Attribute.decode(%Jerboa.Format{}, x, <<>>)
      end
    end
  end

  defp known do
    [0x0020]
  end
end
