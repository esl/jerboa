defmodule Jerboa.Client.Protocol.ChannelBind do
  @moduledoc false

  alias Jerboa.Params
  alias Jerboa.Format.Body.Attribute.XORPeerAddress, as: XPA
  alias Jerboa.Format.Body.Attribute.ChannelNumber

  alias Jerboa.Client
  alias Jerboa.Client.Credentials
  alias Jerboa.Client.Protocol

  @spec request(Credentials.t, peer :: Client.address,
    Jerboa.Format.channel_number) :: Protocol.request
  def request(creds, peer, channel_number) do
    params = params(creds, peer, channel_number)
    Protocol.encode_request(params, creds)
  end

  @spec eval_response(resp :: Params.t, Credentials.t)
    :: :ok | {:error, Client.error, Credentials.t}
  def eval_response(params, creds) do
    with :channel_bind <- Params.get_method(params),
         :success <- Params.get_class(params) do
      :ok
    else
      :failure ->
        Protocol.eval_failure(params, creds)
      _ ->
        {:error, :bad_response, creds}
    end
  end

  ## Internals

  @spec params(Credentials.t, Client.address, Jerboa.Format.channel_number)
    :: Params.t
  defp params(creds, {ip, port}, channel_number) do
    creds
    |> Protocol.base_params()
    |> Params.put_class(:request)
    |> Params.put_method(:channel_bind)
    |> Params.put_attr(XPA.new(ip, port))
    |> Params.put_attr(%ChannelNumber{number: channel_number})
  end
end
