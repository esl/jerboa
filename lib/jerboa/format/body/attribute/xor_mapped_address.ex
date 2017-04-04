defmodule Jerboa.Format.Body.Attribute.XORMappedAddress do
  @moduledoc """
  XOR Mapped Address attribute as defined in the [STUN
  RFC](https://tools.ietf.org/html/rfc5389#section-15.2)
  """

  alias Jerboa.Format.Body.Attribute.XORAddress

  use XORAddress
end
