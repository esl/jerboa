defmodule JerboaTest do
  use ExUnit.Case, async: true

  @moduletag system: true

  setup_all do
    {:ok, alice} = Jerboa.Client.start()
    on_exit fn ->
      :ok = Jerboa.Client.stop(alice)
    end
    {:ok,
     client: alice}
  end

  describe "Jerboa over UDP Transport" do

    test "send binding request; recieve success response", %{client: alice} do

      ## Given:
      import Jerboa.Test.Helper.Server

      ## When:
      x = Jerboa.Client.bind(alice, address: address(), port: port())

      ## Then:
      assert family(x) == "IPv4"
    end

    test "send binding indication", %{client: alice} do

      ## Given:
      import Jerboa.Test.Helper.Server

      ## When:
      x = for _ <- 1..3 do
        Jerboa.Client.persist(alice, address: address(), port: port())
      end

      ## Then:
      assert Enum.all?(x, &ok?/1) == true
    end
  end

  defp family({address, _}) when tuple_size(address) == 4 do
    "IPv4"
  end

  defp ok?(x) do
    x == :ok
  end
end
