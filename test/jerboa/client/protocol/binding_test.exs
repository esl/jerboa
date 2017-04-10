defmodule Jerboa.Client.Protocol.BindingTest do
  use ExUnit.Case

  alias Jerboa.{Params, Format}
  alias Jerboa.Format.Body.Attribute.XORMappedAddress, as: XMA
  alias Jerboa.Client.Protocol.Binding

  test "request/0 returns encoded binding request" do
    {id, request} = Binding.request()

    params = Format.decode!(request)

    assert id == params.identifier
    assert :request == Params.get_class(params)
    assert :binding == Params.get_method(params)
  end

  test "indication/0 returns encoded binding request" do
    request = Binding.indication()

    params = Format.decode!(request)

    assert :indication == Params.get_class(params)
    assert :binding == Params.get_method(params)
  end

  describe "eval_response/1" do
    test "returns server reflexive address on valid binding response" do
      address = {127, 0, 0, 1}
      port = 33_333
      params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:binding)
        |> Params.put_attr(XMA.new(address, port))

      assert {:ok, {address, port}} == Binding.eval_response(params)
    end

    test "returns :bad_response on invalid message class" do
      address = {127, 0, 0, 1}
      port = 33_333
      params =
        Params.new()
        |> Params.put_class(:failure)
        |> Params.put_method(:binding)
        |> Params.put_attr(XMA.new(address, port))

      assert {:error, :bad_response} == Binding.eval_response(params)
    end

    test "returns :bad_response on invalid message method" do
      address = {127, 0, 0, 1}
      port = 33_333
      params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:allocate)
        |> Params.put_attr(XMA.new(address, port))

      assert {:error, :bad_response} == Binding.eval_response(params)
    end

    test "returns :bad_response wihtout XOR-MAPPED-ADDRESS" do
      params =
        Params.new()
        |> Params.put_class(:success)
        |> Params.put_method(:binding)

      assert {:error, :bad_response} == Binding.eval_response(params)
    end
  end
end
