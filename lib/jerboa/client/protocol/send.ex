defmodule Jerboa.Client.Protocol.Send do
  @moduledoc false

  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.XORPeerAddress, as: XPA
  alias Jerboa.Format.Body.Attribute.Data
  alias Jerboa.Client

  @spec indication(peer :: Client.address, data :: binary)
    :: Protocol.indication
  def indication(peer, data) do
    peer
    |> params(data)
    |> Format.encode()
  end

  @spec params(Client.address, binary) :: Params.t
  defp params({address, port}, data) do
    Params.new()
    |> Params.put_class(:indication)
    |> Params.put_method(:send)
    |> Params.put_attr(XPA.new(address, port))
    |> Params.put_attr(%Data{content: data})
  end
end
