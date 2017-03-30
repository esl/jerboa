defmodule Jerboa.Format.Body.Attribute.DontFragmentTest do
  use ExUnit.Case
  use Quixir

  alias Jerboa.Format.Body.Attribute.DontFragment
  alias Jerboa.Format.DontFragment.ValuePresentError
  alias Jerboa.Format.Meta

  describe "decode/1" do
    test "DONT-FRAGMENT attribute without a value (valid)" do
      value = <<>>
      assert {:ok, _, %DontFragment{}} = DontFragment.decode(value, %Meta{})
    end

    test "DONT-FRAGMENT attribute with a value (invalid)" do
      ptest value: string(min: 1) do
        assert {:error, %ValuePresentError{}} = DontFragment.decode(value, %Meta{})
      end
    end
  end

  test "encode/0 DONT-FRAGMENT attribute" do
    assert <<>> = DontFragment.encode()
  end
end
