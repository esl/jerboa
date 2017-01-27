defmodule Jerboa.Params do
  @moduledoc """
  Data structure representing STUN message parameters

  There are two main entities concerning the raw binary: the `header`
  and the `body`. The body encapsulates what it means to encode and
  decode zero or more attributes. It is not an entity described in the
  RFC.
  """

  alias Jerboa.Format.{Header,Body}
  alias Header.Type.{Class, Method}
  alias Body.Attribute

  defstruct [:class, :method, :length, :identifier,
             :header, :body, extra: <<>>, attributes: []]

  @typedoc """
  The main data structure representing STUN message parameters

  The following fields coresspond to the those described in the [STUN
  RFC](https://tools.ietf.org/html/rfc5389#section-6):

  * `class` is one of request, success or failure response, or indincation
  * `method` is a STUN (or TURN) message method described in one of the respective RFCs
  * `length` is the length of the STUN message body in bytes
  * `identifier` is a unique transaction identifier
  * `attributes` is a list of STUN (or TURN) attributes as described in their
  respective RFCs
  * `header` is the raw Elixir binary representation of the STUN header
  initially encoding the `class`, `method`, `length`, `identifier`,
  and magic cookie fields
  * `body` is the raw Elixir binary representation of the STUN attributes
  * `extra` are any bytes after the length given in the STUN header
  """
  @type t :: %__MODULE__{
    class: Class.t,
    method: Method.t,
    length: non_neg_integer,
    identifier: binary,
    attributes: [Attribute.t],
    header: binary,
    body: binary,
    extra: binary
  }
end
