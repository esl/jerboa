defmodule Jerboa.Format do
  @moduledoc """
  Encode and decode the STUN wire format

  There are two main entities concerning the raw binary: the `header`
  and the `body`. The body encapsulates what it means to encode and
  decode zero or more attributes. It is not an entity described in the
  RFC.
  """

  alias Jerboa.Format.{Header,Body}

  defstruct [:class, :method, :length, :identifier,
             :header, :body, excess: <<>>, attributes: []]
  @typedoc """
  The main data structure representing STUN message parameters

  The following fields coresspond to the those described in the [STUN
  RFC](https://tools.ietf.org/html/rfc5389#section-6):

  * `class` is one of request, success or failure response, or indincation
  * `method` is a STUN (or TURN) message method described in one of the respective RFCs
  * `length` is the length of the STUN message body in bytes
  * `identifier` is a unique transaction identifier
  * `attributes` is a list of STUN (or TURN) attributes as described in their respective RFCs
  * `header` is the raw Elixir binary representation of the STUN header
    initially encoding the `class`, `method`, `length`, `identifier`,
    and magic cookie fields
  * `body` is the raw Elixir binary representation of the STUN attributes
  * `excess` are any trialing bytes after the length given in the STUN header

  """
  @type t :: %__MODULE__{
    class: Class.t,
    method: Method.t,
    length: non_neg_integer,
    identifier: binary,
    attributes: [Attribute.t],
    header: binary,
    body: binary,
    excess: binary
  }

  defmodule LengthError do
    defexception [:message, :binary]

    def message(%__MODULE__{binary: b}) do
      "the STUN wire format requires a header of at least 20 bytes but got #{byte_size b} bytes"
    end
  end

  @spec encode(params :: t) :: binary
  @doc """
  Encode a complete set of parameters into a binary suitable writing
  to the network
  """
  def encode(params) do
    params
    |> Header.encode
  end

  @spec decode!(binary) :: t | no_return
  @doc """
  The same as `decode/1` but raises one of various exceptions if the
  binary doesn't encode a STUN message
  """
  def decode!(bin) do
    case decode(bin) do
      {:ok, params} ->
        params
      {:error, e} ->
        raise e
    end
  end

  @spec decode(binary) :: {:ok, t} | {:error, struct}
  @doc """
  Decode a binary into a complete set of STUN message parameters

  Return an `:ok` tuple or an `:error` tuple with an error struct if
  the binary doesn't encode a STUN message.
  """
  def decode(bin) when is_binary(bin) and byte_size(bin) < 20 do
    {:error, LengthError.exception(binary: bin)}
  end
  def decode(<<header::20-binary, body::binary>>) do
    case Header.decode(%Jerboa.Format{header: header, body: body}) do
      {:ok, %Jerboa.Format{body: body, length: length}} when byte_size(body) < length ->
        {:error, Body.LengthError.exception(length: byte_size(body))}
      {:ok, p = %Jerboa.Format{body: body, length: length}} when byte_size(body) > length ->
        <<trimmed_body::size(length)-bytes, excess::binary>> = body
        Body.decode(%{p | excess: excess, body: trimmed_body})
      {:ok, x} ->
        Body.decode(x)
      {:error, _} = e ->
        e
    end
  end
end
