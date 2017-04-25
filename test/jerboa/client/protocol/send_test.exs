defmodule Jerboa.Client.Protocol.SendTest do
  use ExUnit.Case

  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.XORPeerAddress, as: XPA
  alias Jerboa.Format.Body.Attribute.Data
  alias Jerboa.Client.Protocol.Send

  test "indication/2 returns encoded, not signed Send indication" do
    peer_addr = {127, 0, 0, 1}
    peer_port = 12_345
    data = "alicehasacat"

    indication = Send.indication({peer_addr, peer_port}, data)
    params = Format.decode!(indication)

    assert params.class == :indication
    assert params.method == :send
    refute params.signed?
    assert %XPA{address: ^peer_addr, port: ^peer_port} =
      Params.get_attr(params, XPA)
    assert %Data{content: data} == Params.get_attr(params, Data)
  end
end
