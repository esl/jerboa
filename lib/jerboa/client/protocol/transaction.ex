defmodule Jerboa.Client.Protocol.Transaction do
  @moduledoc false

  defstruct req: <<>>, resp: <<>>, id: <<>>

  @type t :: %__MODULE__{
    req: binary,
    resp: binary,
    id: binary
  }
end
