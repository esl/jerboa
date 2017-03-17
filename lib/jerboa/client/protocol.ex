defmodule Jerboa.Client.Protocol do
  @moduledoc false

  ## Pure functions which construct requests or indications
  ## and processes responses

  alias Jerboa.Client
  alias Jerboa.Client.Worker
  alias Jerboa.Client.Protocol.Transaction
  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.XORMappedAddress, as: XMA

  ## API

  @spec init_state(Client.start_opts, Worker.socket) :: Worker.state
  def init_state(opts, socket) do
    %Worker{
      socket: socket,
      server: opts[:server]
    }
  end

  @spec bind_req(Worker.state) :: Worker.state
  def bind_req(state) do
    bind(state, :request)
  end

  @spec bind_ind(Worker.state) :: Worker.state
  def bind_ind(state) do
    bind(state, :indication)
  end

  @spec eval_bind_resp(Worker.state)
  :: {{:ok, mapped_address :: Client.address}, Worker.state}
   | {{:error, :bad_response}, Worker.state}
   | no_return
  def eval_bind_resp(state) do
    case validate_bind_resp(state) do
      {:ok, new_state} ->
        {{:ok, new_state.mapped_address}, new_state}
      error ->
      {error, state}
    end
  end

  ## Internal functions

  @spec bind(Worker.state, :request | :indication) :: Worker.state
  defp bind(state, class) do
    params =
      Params.new()
      |> Params.put_class(class)
      |> Params.put_method(:binding)
    msg = Format.encode(params)
    fill_transaction(state, params.identifier, msg)
  end

  @spec fill_transaction(Worker.state, id :: binary, msg :: binary)
    :: Worker.state
  def fill_transaction(state, id, msg) do
    %{state | transaction: %{state.transaction | req: msg, id: id}}
  end

  @spec validate_bind_resp(Worker.state) :: {:ok, Worker.state} | {:error, :bad_response}
  defp validate_bind_resp(state) do
    transaction = state.transaction
    params = transaction.resp |> Format.decode!()
    with true <- params.identifier == transaction.id,
         %{address: addr, port: port} <- Params.get_attr(params, XMA),
         :binding <- Params.get_method(params),
         :success <- Params.get_class(params) do
      mapped_address = {addr, port}
      {:ok, %{state | mapped_address: mapped_address,
                      transaction: %Transaction{}}}
    else
      _ -> {:error, :bad_response}
    end
  end
end
