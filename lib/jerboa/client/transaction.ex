defmodule Jerboa.Client.Transaction do
  @moduledoc false
  ## Describes transaction to be sent and handled in the future

  alias Jerboa.Params
  alias Jerboa.Client.Credentials
  alias Jerboa.Client.Relay

  defstruct [:caller, :handler, :id]

  @type caller :: GenServer.from
  @type id :: binary
  @type handler :: (response :: Params.t, Credentials.t, Relay.t -> result)
  @type result :: {reply :: term, Credentials.t, Relay.t}

  @type t :: %__MODULE__{
    caller: GenServer.from,
    id: binary,
    handler: handler
  }

  @spec new(caller, id, handler) :: t
  def new(caller, id, handler) do
    %__MODULE__{caller: caller, id: id, handler: handler}
  end
end
