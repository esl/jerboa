defmodule Jerboa.Client.DataHandler do
  @moduledoc false

  defstruct [:fun, :ref, :caller_monitor_ref]

  @type t :: %__MODULE__{
    fun: Client.data_handler,
    ref: reference,
    caller_monitor_ref: reference
  }

  @spec new(Client.data_handler, reference) :: t
  def new(handler_fun, caller_monitor_ref) do
    %__MODULE__{
      fun: handler_fun,
      ref: make_ref(),
      caller_monitor_ref: caller_monitor_ref
    }
  end
end
