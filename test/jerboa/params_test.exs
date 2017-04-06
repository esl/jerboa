defmodule Jerboa.ParamsTest do
  use ExUnit.Case

  alias Jerboa.Params
  alias Jerboa.Format.Body.Attribute
  alias Attribute.{XORMappedAddress, Data}

  test "new/0 returns fresh params struct with ID set" do
    p = Params.new

    assert p.identifier != nil
    assert byte_size(p.identifier) == 12
  end

  test "put_class/2 sets class field" do
    class = :request

    p = Params.new() |> Params.put_class(class)

    assert p.class == class
  end

  test "get_class/1 retrieves class field" do
    class = :request
    p = Params.new() |> Params.put_class(class)

    assert class == Params.get_class(p)
  end

  test "put_method/2 sets method field" do
    method = :binding

    p = Params.new() |> Params.put_method(method)

    assert p.method == method
  end

  test "get_method/1 retrieves method field" do
    method = :binding
    p = Params.new() |> Params.put_method(method)

    assert method == Params.get_method(p)
  end

  test "put_id/2 sets identifier field" do
    id = Params.generate_id()
    p = Params.new() |> Params.put_id(id)

    assert p.identifier == id
  end

  test "get_id/1 retrieves identifier field" do
    id = Params.generate_id()
    p = Params.new() |> Params.put_id(id)

    assert id == Params.get_id(p)
  end

  test "set_attrs/1 sets whole attributes list" do
    params = Params.new() |> Params.put_attr(%Data{})
    attrs = List.duplicate(%XORMappedAddress{}, 3)

    p = params |> Params.set_attrs(attrs)

    assert p.attributes == attrs
  end

  test "get_attrs/1 retrieves whole attributes list" do
    attrs = List.duplicate(%XORMappedAddress{}, 3)
    p = Params.new |> Params.set_attrs(attrs)

    assert attrs == Params.get_attrs(p)
  end

  test "get_attrs/2 retrieves all attributes with given name" do
    attr1 = %XORMappedAddress{family: :ipv4}
    attr2 = %XORMappedAddress{family: :ipv6}
    attr3 = %Data{}

    p = Params.new() |> Params.set_attrs([attr1, attr2, attr3])
    attrs = Params.get_attrs(p, XORMappedAddress)

    assert attr1 in attrs
    assert attr2 in attrs
    refute attr3 in attrs
  end

  describe "put_attr/3" do
    test "adds attribute to attributes list in params struct" do
      attr = %XORMappedAddress{family: :ipv4,
                               address: {127, 0, 0, 1},
                               port: 3333}

      p = Params.new() |> Params.put_attr(attr)

      assert [attr] == Params.get_attrs(p)
    end

    test "overwrites existing attributes with the same name (with overwrite: true)" do
      attr1 = %XORMappedAddress{family: :ipv4, address: {127, 0, 0, 1}, port: 3333}
      attr2 = %XORMappedAddress{family: :ipv6, address: {0, 0, 0, 0, 0, 0, 0, 1},
                                port: 3333}
      attr3 =  %XORMappedAddress{family: :ipv6, address: {0, 0, 0, 0, 0, 0, 0, 1},
                                 port: 1234}

      p =
        Params.new()
        |> Params.set_attrs([attr1, attr2])
        |> Params.put_attr(attr3, overwrite: true)

      assert [attr3] == Params.get_attrs(p)
    end

    test "does not overwrite exisiting attibutes (with overwrite: false)" do
      attr1 = %XORMappedAddress{family: :ipv4, address: {127, 0, 0, 1}, port: 3333}
      attr2 = %XORMappedAddress{family: :ipv6, address: {0, 0, 0, 0, 0, 0, 0, 1},
                                port: 3333}
      attr3 = %Data{}

      p =
        Params.new()
        |> Params.set_attrs([attr1, attr2])
        |> Params.put_attr(attr3, overwrite: true)
      attrs = Params.get_attrs(p)

      assert attr1 in attrs
      assert attr2 in attrs
      assert attr3 in attrs
    end
  end

  describe "get_attr/2" do
    test "retrieves attribute by its name" do
      attr = %XORMappedAddress{family: :ipv4, address: {127, 0, 0, 1}, port: 3333}

      p = Params.new() |> Params.put_attr(attr)

      assert attr == Params.get_attr(p, XORMappedAddress)
    end

    test "returns nil if attribute is not present" do
      p = Params.new

      assert nil == Params.get_attr(p, XORMappedAddress)
    end
  end

  test "put_attrs/2 adds attributes to params struct" do
    attr1 = %XORMappedAddress{family: :ipv4}
    attr2 = %XORMappedAddress{family: :ipv6}
    attr3 = %Data{}

    p =
      Params.new()
      |> Params.set_attrs([attr1])
      |> Params.put_attrs([attr2, attr3])
    attrs = Params.get_attrs(p)

    assert attr1 in attrs
    assert attr2 in attrs
    assert attr3 in attrs
  end
end
