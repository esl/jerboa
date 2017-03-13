defmodule Jerboa.Format.Meta do
  @moduledoc false

  ## Struct getting passed along decoding and encoding process,
  ## keeping decoded data and metadata used for further encoding
  ## and decoding

  alias Jerboa.Params

  defstruct [header: <<>>, body: <<>>, length: 0, extra: <<>>,
             options: [], params: %Params{}]

  # Fields
  # * `:header`- binary header of a message
  # * `:body` - binary body of a message
  # * `:length` - length of body as specified in STUN header
  # * `:extra` - excess part of binary after `:length` bytes
  #   (may happen when reading from TCP stream)
  # * `:options` - additional options passed to encoding and
  #    decoding
  # * `:params` - params being encoded or container for the ones
  #   being decoded
  @type t :: %__MODULE__{
    header: binary,
    body: binary,
    length: non_neg_integer,
    extra: binary,
    options: Keyword.t,
    params: Params.t
  }
end
