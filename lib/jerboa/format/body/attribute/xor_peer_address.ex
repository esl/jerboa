defmodule Jerboa.Format.Body.Attribute.XORPeerAddress do
  @moduledoc """
  XOR-PEER-ADDRESS attribute as defined in the
  [TURN RFC](https://trac.tools.ietf.org/html/rfc5766#section-14.3)
  """

  alias Jerboa.Format.Body.Attribute.XORAddress

  use XORAddress
end
