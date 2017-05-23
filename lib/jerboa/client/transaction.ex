defmodule Jerboa.Client.Transaction do
  @moduledoc false
  ## Describes transaction to be sent and handled in the future

  alias Jerboa.Params
  alias Jerboa.Client.Credentials
  alias Jerboa.Client.Relay

  defstruct [:caller, :handler, :id, :context]

  @type caller :: GenServer.from
  @type id :: binary
  @type context :: map
  @type handler :: (response :: Params.t, Credentials.t, Relay.t,
    context -> result)
  @type result :: {reply :: term, Credentials.t, Relay.t}

  @type t :: %__MODULE__{
    caller: GenServer.from,
    id: id,
    handler: handler,
    context: context
  }

  @spec new(caller, id, handler) :: t
  @spec new(caller, id, handler, context) :: t
  def new(caller, id, handler, context \\ %{}) do
    %__MODULE__{caller: caller, id: id, handler: handler, context: context}
  end
end
