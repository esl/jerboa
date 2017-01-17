defmodule Jerboa.Format.BodyTest do
  use ExUnit.Case, async: true

  alias Jerboa.Test.Helper.XORMappedAddress, as: XORMAHelper

  alias Jerboa.Format
  alias Jerboa.Format.Body

  describe "Body.encode/2" do

    test "one (XORMappedAddress) attribute into one TLV field" do
      attr = XORMAHelper.struct(4)

      %Format{body: bin} = Body.encode %Format{attributes: [attr]}

      assert <<_::16, 8::16, _::64>> = bin
    end
  end

  describe "Body.decode/1" do

    test "unknown comprehension required attribute results in :error tuple" do
      for type <- 0x0000..0x7FFF, not type in known_comprehension_required() do
        body = <<type::16, 0::16>>

        {:error, error} = Body.decode(%Format{body: body})
        assert %Format.ComprehensionError{attribute: ^type} = error
      end
    end

    test "ignores unknown comprehension optional attributes" do
      for type <- 0x8000..0xFFFF, not type in known_comprehension_optional() do
        body = <<type::16, 0::16>>
        assert {:ok, %Format{attributes: []}} = Body.decode(%Format{body: body})
      end
    end
  end

  defp known_comprehension_required do
    [0x0020]
  end

  defp known_comprehension_optional do
    []
  end
end
