defmodule Jerboa.Format.Meta do
  @moduledoc false

  ## Struct getting passed along decoding and encoding process,
  ## keeping decoded data and metadata used for further encoding
  ## and decoding

  alias Jerboa.Params

  defstruct [header: <<>>, body: <<>>, length: 0, extra: <<>>,
             message_integrity: <<>>, length_up_to_integrity: 0,
             options: [], params: %Params{}]

  # Fields
  # * `:header`- binary header of a message
  # * `:body` - binary body of a message
  # * `:length` - length of body as specified in STUN header
  # * `:extra` - excess part of binary after `:length` bytes
  #   (may happen when reading from TCP stream)
  # * `:message_integrity` - value of message integrity hash
  #   extracted from STUN message when decoding
  # * `:length_up_to_integrity` - length of a message body up to
  #   message integrity attribute, in bytes
  # * `:options` - additional options passed to encoding and
  #    decoding
  # * `:params` - params being encoded or container for the ones
  #   being decoded
  @type t :: %__MODULE__{
    header: binary,
    body: binary,
    length: non_neg_integer,
    extra: binary,
    message_integrity: binary,
    length_up_to_integrity: non_neg_integer,
    options: Keyword.t,
    params: Params.t
  }
end
