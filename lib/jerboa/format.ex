defmodule Jerboa.Format do
  @moduledoc """

  Encode and decode the STUN wire format. There are two entities
  concerning the raw binary: the `head' and the `body'. The body
  encapsulates what it means to encode and decode zero or more
  attributes. It is not an entity described in the RFC.

  """

  alias Jerboa.Format.{Head,Body}

  defstruct [:class, :method, :length, :identifier,
             :head, :body, excess: <<>>, attributes: []]

  defmodule BinaryTooShort do
    defexception [:message, :binary]

    def message(%__MODULE__{binary: b}) do
      "The STUN wire format requires a header of at least 20 bytes. Got #{byte_size b} bytes."
    end
  end

  def encode(params) do
    params
    |> Head.encode
  end

  def decode!(bin) do
    case decode(bin) do
      {:ok, value} ->
        value
      {:error, e} ->
        raise e
    end
  end

  def decode(bin) when is_binary(bin) and byte_size(bin) < 20 do
    {:error, BinaryTooShort.exception(binary: bin)}
  end
  def decode(<<head::20-binary, body::binary>>) do
    case Head.decode(%Jerboa.Format{head: head, body: body}) do
      {:ok, x} ->
        Body.decode(x)
      {:error, _} = e ->
        e
    end
  end
end
