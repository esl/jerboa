defmodule Jerboa.Client.Protocol do
  @moduledoc false

  alias Jerboa.Client
  alias Jerboa.Client.Credentials
  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.{Username, Realm, Nonce, ErrorCode}

  require Logger

  @type request :: {id :: binary, packet :: binary}
  @type indication :: binary

  ## API

  @spec encode_request(Params.t, Crendetials.t) :: request
  def encode_request(params, creds) do
    opts = Credentials.to_decode_opts(creds)
    {params.identifier, Format.encode(params, opts)}
  end

  @spec decode!(packet :: binary, Credentials.t) :: Params.t | no_return
  def decode!(packet, creds) do
    opts = Credentials.to_decode_opts(creds)
    Format.decode!(packet, opts)
  end

  @spec base_params(Credentials.t) :: Params.t
  def base_params(creds) do
    params = Params.new()
    if Credentials.complete?(creds) do
      params
      |> Params.put_attr(%Username{value: creds.username})
      |> Params.put_attr(%Realm{value: creds.realm})
      |> Params.put_attr(%Nonce{value: creds.nonce})
    else
      params
    end
  end

  @spec eval_failure(resp :: Params.t, Credentials.t)
    :: {:error, Client.error, Credentials.t}
  def eval_failure(params, creds) do
    nonce_attr = Params.get_attr(params, Nonce)
    error = Params.get_attr(params, ErrorCode)
    cond do
      is_nil error ->
        {:error, :bad_response, creds}
      error.name == :stale_nonce && nonce_attr ->
        new_creds = %{creds | nonce: nonce_attr.value}
        {:error, error.name, new_creds}
      true ->
        {:error, error.name, creds}
    end
  end
end
