defmodule Jerboa.Client.Worker do
  @moduledoc false

  use GenServer

  alias :gen_udp, as: UDP
  alias Jerboa.Params
  alias Jerboa.Format.Body.Attribute.XORMappedAddress
  alias Jerboa.Format

  import Kernel, except: [binding: 1]

  defstruct [:server, :socket, :mapped_address]

  @type address :: {Jerboa.Client.ip, Jerboa.Client.port_no}
  @type t :: %__MODULE__{
    server: address,
    socket: UDP.socket,
    mapped_address: address
  }

  @system_allocated_port 0

  def start_link(x) do
    GenServer.start_link(__MODULE__, x)
  end

  def init(address: a, port: p) do
    false = Process.flag(:trap_exit, true)
    {:ok, socket} = UDP.open(@system_allocated_port, [:binary, active: false])
    {:ok,
     %__MODULE__{server: {a, p}, socket: socket}}
  end

  def handle_call(:bind, _, state) do
    msg = binding(:request)
    params = request(msg, state)
    state = %{state | mapped_address: mapped_address(params)}
    {:reply, state.mapped_address, state}
  end


  def handle_cast(:persist, state) do
    msg = binding(:indication)
    indication(msg, state)
    {:noreply, state}
  end

  def terminate(_, state) do
    :ok = UDP.close(socket(state))
  end

  defp server(%__MODULE__{server: s}) do
    s
  end

  defp socket(%__MODULE__{socket: s}) do
    s
  end

  defp binding(class) do
    Params.new()
    |> Params.put_class(class)
    |> Params.put_method(:binding)
    |> Format.encode()
  end

  defp mapped_address(params) do
    xor_mapped_addr = Params.get_attr(params, XORMappedAddress)
    {xor_mapped_addr.address, xor_mapped_addr.port}
  end

  defp request(msg, state) do
    socket = socket(state)
    {address, port} = server(state)
    :ok = UDP.send(socket, address, port, msg)
    {:ok, {^address, ^port, response}} = UDP.recv(socket, 0, timeout())
    Format.decode!(response)
  end

  defp indication(msg, state) do
    socket = socket(state)
    {address, port} = server(state)
    :ok = UDP.send(socket, address, port, msg)
  end

  def timeout do
    Keyword.fetch!(Application.fetch_env!(:jerboa, :client), :timeout)
  end
end
