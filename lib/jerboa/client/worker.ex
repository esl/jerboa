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
    msg = Jerboa.Format.encode(Jerboa.Params.put_class(binding_(), :request))
    response = call(socket(state), a, p, msg)
    {:ok, params} = Jerboa.Format.decode(response)
    {:reply, reflexive_candidate(params), state}
  end
  def handle_call({:persist, a, p}, _, state) do
    msg = Jerboa.Format.encode(Jerboa.Params.put_class(binding_(), :indication))
    {:reply, cast(socket(state), a, p, msg), state}
  end

  def terminate(_, state) do
    :ok = UDP.close(socket(state))
  end

  defp socket(%__MODULE__{socket: s}) do
    s
  end

  defp binding_ do
    %Jerboa.Params{
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

  defp call(socket, address, port, request) do
    :ok = UDP.send(socket, address, port, request)
    {:ok, {^address, ^port, response}} = UDP.recv(socket, 0, timeout())
    response
  end

  defp cast(socket, address, port, indication) do
    :ok = UDP.send(socket, address, port, indication)
    {:error, :timeout} = UDP.recv(socket, 0, timeout())
    :ok
  end

  def timeout do
    Keyword.fetch!(Application.fetch_env!(:jerboa, :client), :timeout)
  end
end
