defmodule JerboaTest do
  use ExUnit.Case, async: true

  alias Jerboa.Format.Body.Attribute
  alias Jerboa.Params

  @moduletag system: true
  @google_ip {74, 125, 143, 127}
  @google_port 19_302

  test "binding request and response on UDP" do
    {:ok, socket} = :gen_udp.open(4096, [:binary, active: false])

    :ok = :gen_udp.send(socket, @google_ip, @google_port, binding_request())
    {:ok, {_, _, response}} = :gen_udp.recv(socket, 0)
    :ok = :gen_udp.close(socket)

    assert {:ok,
            %Params{
              class: :success,
              method: :binding,
              attributes: [a]}} = Jerboa.Format.decode response
    assert %Attribute{
      name: Attribute.XORMappedAddress,
      value: %Attribute.XORMappedAddress{
        family: :ipv4,
        address: {_,_,_,_},
        port: _}} = a
  end

  def binding_request do
    Jerboa.Format.encode %Params{
      class: :request,
      method: :binding,
      identifier: :crypto.strong_rand_bytes(div 96, 8),
      body: <<>>}
  end
end
