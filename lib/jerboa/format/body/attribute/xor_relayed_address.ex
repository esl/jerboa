defmodule Jerboa.Format.Body.Attribute.XORRelayedAddress do
  @moduledoc """
  XOR-RELAYED-ADDRESS attribute as defined in the
  [TURN RFC](https://trac.tools.ietf.org/html/rfc5766#section-14.5)
  """

  alias Jerboa.Format.Body.Attribute.XORAddress

  use XORAddress
end
