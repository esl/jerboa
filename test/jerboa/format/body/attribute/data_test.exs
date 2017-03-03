defmodule Jerboa.Format.Body.Attribute.DataTest do
  use ExUnit.Case
  use Quixir

  alias Jerboa.Format.Body.Attribute.Data

  test "decode/1 DATA attribute" do
    ptest content: string() do
      assert {:ok, %Data{content: content}} == Data.decode(content)
    end
  end

  describe "encode/1" do
    test "DATA attribute with binary content" do
      ptest content: string() do
        assert content == %Data{content: content} |> Data.encode()
      end
    end

    test "DATA attribute with non-binary content" do
      assert_raise FunctionClauseError, fn ->
        %Data{content: 1} |> Data.encode()
      end
    end
  end

end
