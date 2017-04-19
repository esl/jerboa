defmodule Jerboa.Client.DataHandler do
  @moduledoc false

  defstruct [:fun, :ref]

  @type t :: %__MODULE__{
    fun: Client.data_handler,
    ref: reference
  }

  @spec new(Client.data_handler) :: t
  def new(handler_fun) do
    %__MODULE__{
      fun: handler_fun,
      ref: make_ref()
    }
  end
end
