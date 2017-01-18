defmodule Jerboa.Test.Helper.XORMappedAddress do
  @moduledoc false

  alias Jerboa.Format.Body.Attribute.XORMappedAddress

  def struct(4) do
    struct(:ipv4, ip_4_a(), port())
  end
  def struct(6) do
    struct(:ipv6, ip_6_a(), port())
  end

  def ip_4_a do
    {0, 0, 0, 0}
  end

  def ip_6_a do
    :erlang.make_tuple(16, 0)
  end

  def port, do: 0

  def i do
    :crypto.strong_rand_bytes(div(96, 8))
  end

  defp struct(f, a, p) do
    %XORMappedAddress{family: f, address: a, port: p}
  end
end
