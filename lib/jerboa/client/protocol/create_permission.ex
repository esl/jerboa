defmodule Jerboa.Client.Protocol.CreatePermission do
  @moduledoc false

  alias Jerboa.Params
  alias Jerboa.Format.Body.Attribute.XORPeerAddress, as: XPA
  alias Jerboa.Client
  alias Jerboa.Client.Protocol
  alias Jerboa.Client.Credentials

  @spec request(Credentials.t, peer_addrs :: [Client.ip, ...])
    :: Protocol.request
  def request(creds, peer_addrs) do
    params = params(creds, peer_addrs)
    Protocol.encode_request(params, creds)
  end

  @spec eval_response(response :: Params.t, Credentials.t)
    :: :ok | {:error, Client.error, Credentials.t}
  def eval_response(params, creds) do
    with :create_permission <- Params.get_method(params),
         :success <- Params.get_class(params) do
      :ok
    else
      :failure ->
        Protocol.eval_failure(params, creds)
      _ ->
        {:error, :bad_response, creds}
    end
  end

  @spec params(Credentials.t, [Client.ip, ...]) :: Params.t
  defp params(creds, peer_addrs) do
    xor_peer_addrs = Enum.map peer_addrs, fn addr -> XPA.new(addr, 0) end
    creds
    |> Protocol.base_params()
    |> Params.put_class(:request)
    |> Params.put_method(:create_permission)
    |> Params.put_attrs(xor_peer_addrs)
  end
end
