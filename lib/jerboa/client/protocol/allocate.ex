defmodule Jerboa.Client.Protocol.Allocate do
  @moduledoc false

  alias Jerboa.Params
  alias Jerboa.Format.Body.Attribute.XORMappedAddress, as: XMA
  alias Jerboa.Format.Body.Attribute.XORRelayedAddress, as: XRA
  alias Jerboa.Format.Body.Attribute.{RequestedTransport, Lifetime, Realm,
                                      Nonce, ErrorCode, EvenPort,
                                      ReservationToken}
  alias Jerboa.Client
  alias Jerboa.Client.Protocol
  alias Jerboa.Client.Credentials

  @spec request(Credentials.t, Client.allocate_opts) :: Protocol.request
  def request(creds, opts) do
    params = params(creds, opts)
    Protocol.encode_request(params, creds)
  end

  @spec eval_response(response :: Params.t, Credentials.t, Client.allocate_opts)
    :: {:ok, relayed_address :: Client.address, lifetime :: non_neg_integer}
     | {:ok, Client.address, non_neg_integer, reservation_token :: binary}
     | {:error, Client.error, Credentials.t}
  def eval_response(params, creds, opts) do
    with :allocate <- Params.get_method(params),
         :success <- Params.get_class(params),
         %{address: raddr, port: rport, family: :ipv4} <- Params.get_attr(params, XRA),
         %XMA{} <- Params.get_attr(params, XMA),
         %{duration: lifetime} <- Params.get_attr(params, Lifetime),
         :ok <- check_reservation_token(params, opts) do
      relayed_address = {raddr, rport}
      maybe_with_reservation_token(relayed_address, lifetime, params, opts)
    else
      :failure ->
        eval_failure(params, creds)
      _ ->
        {:error, :bad_response, creds}
    end
  end

  @spec check_reservation_token(Params.t, Client.allocate_opts) :: :ok | :error
  defp check_reservation_token(params, opts) do
    with {:ok, true} <- Keyword.fetch(opts, :reserve),
         %ReservationToken{} <- Params.get_attr(params, ReservationToken) do
      :ok
    else
      {:ok, _} ->
        :ok
      :error ->
        :ok
      _ ->
        :error
    end
  end

  @spec maybe_with_reservation_token(Client.address, non_neg_integer, Params.t,
    Client.allocate_opts)
    :: {:ok, relayed_address :: Client.address, lifetime :: non_neg_integer}
     | {:ok, Client.address, non_neg_integer, reservation_token :: binary}
  defp maybe_with_reservation_token(relayed_address, lifetime, params, opts) do
    case Keyword.fetch(opts, :reserve) do
      {:ok, true} ->
         %ReservationToken{value: token} = Params.get_attr(params, ReservationToken)
        {:ok, relayed_address, lifetime, token}
        _ ->
        {:ok, relayed_address, lifetime}
    end
  end

  @spec params(Credentials.t, Client.allocate_opts) :: Params.t
  defp params(creds, opts) do
    params =
      creds
      |> Protocol.base_params()
      |> Params.put_class(:request)
      |> Params.put_method(:allocate)
      |> Params.put_attr(%RequestedTransport{})
    cond do
      opts[:reservation_token] ->
        token = opts[:reservation_token]
        params |> Params.put_attr(%ReservationToken{value: token})
      opts[:reserve] == true ->
        params |> Params.put_attr(%EvenPort{reserved?: true})
      opts[:even_port] == true ->
        params |> Params.put_attr(%EvenPort{reserved?: false})
      true ->
        params
    end
  end

  @spec eval_failure(resp :: Params.t, Credentials.t)
    :: {:error, Client.error, Credentials.t}
  defp eval_failure(params, creds) do
    realm_attr = Params.get_attr(params, Realm)
    nonce_attr = Params.get_attr(params, Nonce)
    error = Params.get_attr(params, ErrorCode)
    cond do
      is_nil error ->
        {:error, :bad_response, creds}
      should_finalize_creds?(creds, error.name, realm_attr, nonce_attr) ->
        new_creds =
          Credentials.finalize(creds, realm_attr.value, nonce_attr.value)
        {:error, error.name, new_creds}
      error.name == :stale_nonce && nonce_attr ->
        new_creds = %{creds | nonce: nonce_attr.value}
        {:error, error.name, new_creds}
      true ->
        {:error, error.name, creds}
    end
    end

  @spec should_finalize_creds?(Credentials.t, ErrorCode.name,
    Realm.t | nil, Nonce.t | nil) :: boolean
  defp should_finalize_creds?(creds, :unauthorized, %Realm{}, %Nonce{}) do
    not Credentials.complete?(creds)
  end
  defp should_finalize_creds?(_, _, _, _), do: false
end
