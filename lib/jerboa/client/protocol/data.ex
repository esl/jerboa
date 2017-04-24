defmodule Jerboa.Client.Protocol.Data do
  @moduledoc false

  alias Jerboa.Params
  alias Jerboa.Format.Body.Attribute.XORPeerAddress, as: XPA
  alias Jerboa.Format.Body.Attribute.Data
  alias Jerboa.Client

  @spec eval_indication(Params.t)
    :: {:ok, peer :: Client.address, binary} | :error
  def eval_indication(params) do
    with :indication <- Params.get_class(params),
         :data <- Params.get_method(params),
         %Data{content: data} <- Params.get_attr(params, Data),
         %XPA{address: addr, port: port} <- Params.get_attr(params, XPA) do
      {:ok, {addr, port}, data}
    else
      _ -> :error
    end
  end
end
