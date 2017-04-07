defmodule Jerboa.Client.Protocol do
  @moduledoc false

  ## Pure functions which construct requests or indications
  ## and process responses

  alias Jerboa.Client
  alias Jerboa.Client.Worker
  alias Jerboa.Client.Protocol.Transaction
  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.XORMappedAddress, as: XMA
  alias Jerboa.Format.Body.Attribute.XORRelayedAddress, as: XRA
  alias Jerboa.Format.Body.Attribute.XORPeerAddress, as: XPA
  alias Jerboa.Format.Body.Attribute.{RequestedTransport, Username, Realm,
                                      Nonce, Lifetime, ErrorCode}

  require Logger

  ## API

  @spec bind_req(Worker.state) :: Worker.state
  def bind_req(state) do
    Logger.debug fn -> "Sending binding request to the server" end
    bind(state, :request)
  end

  @spec bind_ind(Worker.state) :: Worker.state
  def bind_ind(state) do
    Logger.debug fn -> "Sending binding indication to the server" end
    bind(state, :indication)
  end

  @spec eval_bind_resp(Worker.state)
  :: {{:ok, mapped_address :: Client.address}, Worker.state}
   | {{:error, :bad_response}, Worker.state}
   | no_return
  def eval_bind_resp(state) do
    case validate_bind_resp(state) do
      {:ok, new_state} ->
        mapped_address = new_state.mapped_address
        Logger.debug fn ->
          "Received success binding response, server reflexive address: " <>
            Client.format_address(mapped_address)
        end
        {{:ok, mapped_address}, empty_transaction(new_state)}
      {:error, reason} = error ->
        Logger.debug fn ->
          "Error when receiving binding response, reason: #{inspect reason}"
        end
        {error, state}
    end
  end

  @spec allocate_req(Worker.state) :: Worker.state
  def allocate_req(state) do
    Logger.debug fn -> "Sending allocate request to the server" end
    params = allocate_params(state)
    encode_request(params, state)
  end

  @spec eval_allocate_resp(Worker.state)
    :: {{:ok, relayed_address :: Client.address}, Worker.state}
     | {{:error, Client.error}, Worker.state}
     | {:retry, Worker.state}
  def eval_allocate_resp(state) do
    case handle_allocate_resp(state) do
      {:ok, new_state} ->
        relayed_address = new_state.relay.address
        Logger.debug fn ->
          "Received success allocate reponse, relayed address: " <>
            Client.format_address(relayed_address)
        end
        {{:ok, relayed_address}, empty_transaction(new_state)}
      {:error, reason} ->
        Logger.debug fn ->
          "Error when receiving allocate response, reason: #{inspect reason}"
        end
        {{:error, reason}, empty_transaction(state)}
      {:retry, new_state} ->
        {:retry, empty_transaction(new_state)}
    end
  end

  @spec refresh_req(Worker.state) :: Worker.state
  def refresh_req(state) do
    Logger.debug fn -> "Sending refresh request to the server" end
    params = refresh_params(state)
    encode_request(params, state)
  end

  @spec eval_refresh_resp(Worker.state)
    :: {:ok, Worker.state}
     | {{:error, Client.error}, Worker.state}
     | {:retry, Worker.state}
  def eval_refresh_resp(state) do
    case handle_refresh_resp(state) do
      {:ok, new_state} ->
        Logger.debug fn ->
          "Received success refresh reponse, new lifetime: " <>
            "#{new_state.lifetime}"
        end
        {:ok, empty_transaction(new_state)}
      {:error, reason} ->
        Logger.debug fn ->
          "Error when receiving refresh response, reason: #{inspect reason}"
        end
        {{:error, reason}, empty_transaction(state)}
      {:retry, new_state} ->
        {:retry, empty_transaction(new_state)}
    end
  end

  @spec create_perm_req(Worker.state, peer_addrs :: [Client.ip, ...])
    :: Worker.state
  def create_perm_req(state, peer_addrs) do
    Logger.debug fn -> "Sending create permission request to the server" end
    params = create_perm_params(state, peer_addrs)
    encode_request(params, state)
  end

  @spec eval_create_perm_resp(Worker.state)
    :: {:ok, Worker.state}
     | {{:error, Client.error}, Worker.state}
     | {:retry, Worker.state}
  def eval_create_perm_resp(state) do
    case handle_create_perm_resp(state) do
      {:ok, new_state} ->
        Logger.debug fn ->
          "Received success create permission reponse"
        end
        {:ok, empty_transaction(new_state)}
      {:error, reason} ->
        Logger.debug fn ->
          "Error when receiving create permission response, " <>
            "reason: #{inspect reason}"
        end
        {{:error, reason}, empty_transaction(state)}
      {:retry, new_state} ->
        {:retry, empty_transaction(new_state)}
    end
  end

  ## Internal functions

  @spec bind(Worker.state, :request | :indication) :: Worker.state
  defp bind(state, class) do
    params =
      Params.new()
      |> Params.put_class(class)
      |> Params.put_method(:binding)
    encode_request(params, state)
   end

  @spec validate_bind_resp(Worker.state)
    :: {:ok, Worker.state} | {:error, :bad_response}
  defp validate_bind_resp(state) do
    params = decode_response(state)
    with :ok <- validate_transaction_id(params, state),
         %{address: addr, port: port} <- Params.get_attr(params, XMA),
         :binding <- Params.get_method(params),
         :success <- Params.get_class(params) do
      mapped_address = {addr, port}
      {:ok, %{state | mapped_address: mapped_address}}
    else
      _ -> {:error, :bad_response}
    end
  end

  @spec allocate_params(Worker.state) :: Params.t
  defp allocate_params(state) do
    base =
      Params.new()
      |> Params.put_class(:request)
      |> Params.put_method(:allocate)
      |> Params.put_attr(%RequestedTransport{})

    if state.credentials.realm do
      base
      |> Params.put_attr(%Username{value: state.credentials.username})
      |> Params.put_attr(%Realm{value: state.credentials.realm})
      |> Params.put_attr(%Nonce{value: state.credentials.nonce})
    else
      base
    end
  end

  @spec encode_request(Params.t, Worker.state) :: Worker.state
  defp encode_request(params, state) do
    opts =
      if state.credentials.realm do
        [secret: state.credentials.secret,
         realm: state.credentials.realm,
         username: state.credentials.username]
      else
        []
      end
    msg = Format.encode(params, opts)
    %{state | transaction: %Transaction{req: msg, id: params.identifier}}
  end

  @spec decode_response(Worker.state) :: Params.t
  def decode_response(state) do
    opts =
      if state.credentials.realm do
        [secret: state.credentials.secret,
         realm: state.credentials.realm,
         username: state.credentials.username]
      else
        []
      end
    msg = state.transaction.resp
    Format.decode!(msg, opts)
  end

  @spec handle_allocate_resp(Worker.state)
    :: {:ok, Worker.state} | {:error, Client.error} | {:retry, Worker.state}
  defp handle_allocate_resp(state) do
    params = decode_response(state)
    with :ok <- validate_transaction_id(params, state),
         :allocate <- Params.get_method(params),
         :success <- Params.get_class(params),
         %{address: raddr, port: rport, family: :ipv4} <- Params.get_attr(params, XRA),
         %{address: maddr, port: mport, family: :ipv4} <- Params.get_attr(params, XMA),
         %{duration: lifetime} <- Params.get_attr(params, Lifetime) do
      relayed_address = {raddr, rport}
      mapped_address = {maddr, mport}
      relay = %{state.relay | lifetime: lifetime, address: relayed_address}
      new_state = %{state | relay: relay,
                            mapped_address: mapped_address}
      {:ok, new_state}
    else
      :failure ->
        handle_allocate_failure(state, params)
      _ ->
        {:error, :bad_response}
    end
  end

  @spec handle_allocate_failure(Worker.state, resp :: Params.t)
    :: {:retry, Worker.state} | {:error, Client.error}
  defp handle_allocate_failure(state, params) do
    realm_attr = Params.get_attr(params, Realm)
    nonce_attr = Params.get_attr(params, Nonce)
    error = Params.get_attr(params, ErrorCode)
    cond do
      is_nil error ->
        {:error, :bad_response}
      error.name == :unauthorized && is_nil(state.credentials.realm) && realm_attr && nonce_attr ->
        new_credentials = %{state.credentials | realm: realm_attr.value, nonce: nonce_attr.value}
        new_state = %{state | credentials: new_credentials}
        {:retry, new_state}
      error.name == :stale_nonce && nonce_attr ->
        new_credentials = %{state.credentials | nonce: nonce_attr.value}
        new_state = %{state | credentials: new_credentials}
        {:retry, new_state}
      true ->
        {:error, error.name}
    end
  end

  @spec empty_transaction(Worker.state) :: Worker.state
  defp empty_transaction(state) do
    %{state | transaction: %Transaction{}}
  end

  @spec validate_transaction_id(Params.t, Worker.state) :: :ok | :error
  defp validate_transaction_id(params, state) do
    if params.identifier == state.transaction.id do
      :ok
    else
      :error
    end
  end

  @spec refresh_params(Worker.state) :: Params.t
  defp refresh_params(state) do
    Params.new()
    |> Params.put_class(:request)
    |> Params.put_method(:refresh)
    |> Params.put_attr(%Username{value: state.credentials.username})
    |> Params.put_attr(%Realm{value: state.credentials.realm})
    |> Params.put_attr(%Nonce{value: state.credentials.nonce})
  end

  @spec handle_refresh_resp(Worker.state)
    :: {:ok, Worker.state} | {:error, Client.error} | {:retry, Worker.state}
  defp handle_refresh_resp(state) do
    params = decode_response(state)
    with :ok <- validate_transaction_id(params, state),
         :refresh <- Params.get_method(params),
         :success <- Params.get_class(params),
         %{duration: lifetime} <- Params.get_attr(params, Lifetime) do
      relay = %{state.relay | lifetime: lifetime}
      new_state = %{state | relay: relay}
      {:ok, new_state}
    else
      :failure ->
           maybe_retry_with_stale_nonce(state, params)
      _ ->
        {:error, :bad_response}
    end
  end

  @spec maybe_retry_with_stale_nonce(Worker.state, resp :: Params.t)
    :: {:retry, Worker.state} | {:error, Client.error}
  defp maybe_retry_with_stale_nonce(state, params) do
    nonce_attr = Params.get_attr(params, Nonce)
    error = Params.get_attr(params, ErrorCode)
    cond do
      is_nil error ->
        {:error, :bad_response}
      error.name == :stale_nonce && nonce_attr ->
        new_credentials = %{state.credentials | nonce: nonce_attr.value}
        new_state = %{state | credentials: new_credentials}
        {:retry, new_state}
      true ->
        {:error, error.name}
    end
  end

  @spec create_perm_params(Worker.state, [Client.ip, ...]) :: Params.t
  defp create_perm_params(state, peer_addrs) do
    xor_peer_addrs = Enum.map peer_addrs, fn addr -> XPA.new(addr, 0) end
    Params.new()
    |> Params.put_class(:request)
    |> Params.put_method(:create_permission)
    |> Params.put_attr(%Username{value: state.credentials.username})
    |> Params.put_attr(%Realm{value: state.credentials.realm})
    |> Params.put_attr(%Nonce{value: state.credentials.nonce})
    |> Params.put_attrs(xor_peer_addrs)
  end

  @spec handle_create_perm_resp(Worker.state)
    :: {:ok, Worker.state} | {:error, Client.error} | {:retry, Worker.state}
  defp handle_create_perm_resp(state) do
    params = decode_response(state)
    with :ok <- validate_transaction_id(params, state),
         :create_permission <- Params.get_method(params),
         :success <- Params.get_class(params) do
      {:ok, state}
    else
      :failure ->
           maybe_retry_with_stale_nonce(state, params)
      _ ->
        {:error, :bad_response}
    end
  end
end
