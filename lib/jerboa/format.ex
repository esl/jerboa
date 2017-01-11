defmodule Jerboa.Format do
  @moduledoc """

  Encode and decode the STUN wire format. There are two entities: the
  `head' and the `body'. The body encapsulates what it means to encode
  and decode zero or more attributes. It is not an entity described in
  the RFC.

  """
  alias Jerboa.Format.{Head,Body}

  defstruct [:class, :method, :length, :identifier, :attributes, :head, :body]

  def encode(params) do
    params
    |> Head.encode
  end

  def decode(<<x::20-binary, y::binary>>) do
    %Jerboa.Format{head: x, body: y}
    |> Head.decode
    |> Body.decode
  end
end
