defmodule Jerboa.Client.Protocol.Refresh do
  @moduledoc false

  alias Jerboa.Params
  alias Jerboa.Format.Body.Attribute.Lifetime
  alias Jerboa.Client
  alias Jerboa.Client.Protocol
  alias Jerboa.Client.Credentials

  @spec request(Credentials.t) :: Protocol.request
  def request(creds) do
    params = params(creds)
    Protocol.encode_request(params, creds)
  end

  @spec eval_response(response :: Params.t, Credentials.t)
    :: {:ok, lifetime :: non_neg_integer}
     | {:error, Client.error, Credentials.t}
  def eval_response(params, creds) do
    with :refresh <- Params.get_method(params),
         :success <- Params.get_class(params),
         %{duration: lifetime} <- Params.get_attr(params, Lifetime) do
      {:ok, lifetime}
    else
      :failure ->
        Protocol.eval_failure(params, creds)
      _ ->
        {:error, :bad_response, creds}
    end
  end

  @spec params(Credentials.t) :: Params.t
  defp params(creds) do
    creds
    |> Protocol.base_params()
    |> Params.put_class(:request)
    |> Params.put_method(:refresh)
  end
end
