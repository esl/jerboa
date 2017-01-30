defmodule Jerboa.Client.Worker do
  @moduledoc false

  use GenServer

  alias :gen_udp, as: UDP

  defstruct [:socket]

  def start_link(port \\ 4096) do
    GenServer.start_link(__MODULE__, port)
  end

  def init(p) do
    false = Process.flag(:trap_exit, true)
    {:ok, s} = UDP.open(p, [:binary, active: false])
    {:ok,
     %__MODULE__{socket: s}}
  end

  def handle_call({:bind, a, p}, _, state) do

    msg = Jerboa.Format.encode(binding_request())
    :ok = UDP.send(socket(state), a, p, msg)
    {:ok, {_, _, response}} = UDP.recv(socket(state), 0)
    {:ok, params} = Jerboa.Format.decode(response)

    {:reply, reflexive_candidate(params), state}
  end

  def terminate(_, state) do
    :ok = UDP.close(socket(state))
  end

  defp socket(%__MODULE__{socket: s}) do
    s
  end

  defp binding_request do
    %Jerboa.Params{
      class: :request,
      method: :binding,
      identifier: :crypto.strong_rand_bytes(div(96, 8)),
      body: <<>>
    }
  end

  defp reflexive_candidate(%Jerboa.Params{attributes: [%{value: a}]}) do
    alias Jerboa.Format.Body.Attribute.XORMappedAddress
    %XORMappedAddress{address: x, port: y} = a
    {x, y}
  end
end
