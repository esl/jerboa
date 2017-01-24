defmodule JerboaTest do
  use ExUnit.Case, async: true

  @moduletag system: true

  describe "Jerboa over UDP Transport" do

    test "send binding request; recieve success response" do

      ## Given:
      alias Jerboa.Test.Helper.Server
      alias Jerboa.Test.Helper.Format
      {:ok, socket} = :gen_udp.open(4096, [:binary, active: false])

      ## When:
      msg = Jerboa.Format.encode(Format.binding_request())
      :ok = :gen_udp.send(socket, Server.a(), Server.p(), msg)
      {:ok, {_, _, response}} = :gen_udp.recv(socket, 0)
      {:ok, p} = Jerboa.Format.decode(response)

      ## Then:
      assert Jerboa.Format.class(p) == :success
      assert Jerboa.Format.method(p) == :binding
      :ok = :gen_udp.close(socket)
    end
  end
end
