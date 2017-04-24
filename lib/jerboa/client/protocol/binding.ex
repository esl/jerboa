defmodule Jerboa.Client.Protocol.Binding do
  @moduledoc false

  alias Jerboa.Params
  alias Jerboa.Format
  alias Jerboa.Format.Body.Attribute.XORMappedAddress, as: XMA
  alias Jerboa.Client
  alias Jerboa.Client.Protocol

  @spec request :: Protocol.request
  def request do
    params = params(:request)
    {params.identifier, Format.encode(params)}
  end

  @spec eval_response(response :: Params.t)
    :: {:ok, mapped_address :: Client.address} | {:error, :bad_response}
  def eval_response(params) do
    with %{address: addr, port: port} <- Params.get_attr(params, XMA),
         :binding <- Params.get_method(params),
         :success <- Params.get_class(params) do
      {:ok, {addr, port}}
    else
      _ -> {:error, :bad_response}
    end
  end

  @spec indication :: Protocol.indication
  def indication do
    :indication
    |> params()
    |> Format.encode()
  end

  @spec params(:request | :indication) :: Params.t
  defp params(class) do
      Params.new()
      |> Params.put_class(class)
      |> Params.put_method(:binding)
   end
end
