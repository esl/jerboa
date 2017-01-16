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

  defmodule HeaderLengthError do
    defexception [:message, :binary]

    def exception(binary: b) do
      %__MODULE__{binary: b,
                  message: "the STUN wire format requires a header of at least" <>
                           " 20 bytes but got #{byte_size b} bytes"}
    end
  end

  defmodule BodyLengthError do
    defexception [:message, :length]

    def exception(length: l) do
      %__MODULE__{length: l,
                  message: "message body is shorter than specified length"}
    end
  end

  defmodule First2BitsError do
    defexception [:message, :bits]

    def exception(bits: b) do
      %__MODULE__{bits: b,
                  message: "the most significant two bits of a STUN " <>
                           "message must be zeros"}
    end
  end

  defmodule MagicCookieError do
    defexception [:message, :header]

    def exception(header: h) do
      %__MODULE__{header: h,
                  message: "STUN message doesn't have magic cookie"}
    end
  end

  defmodule UnknownMethodError do
    defexception [:message, :method]

    def exception(method: m) do
      %__MODULE__{method: m,
                  message: "unknown STUN method 0x#{Integer.to_string(m, 16)}"}
    end
  end

  defmodule Last2BitsError do
    defexception [:message, :length]

    def exception(length: l) do
      %__MODULE__{length: l,
                  message: "all STUN attributes are padded to a multiple of 4 bytes" <>
                           " so the last 2 bits of this field should be zero"}
    end
  end

  defmodule ComprehensionError do
    defexception [:message, :attribute]

    def exception(attribute: n) do
      %__MODULE__{attribute: n,
                  message: "can not encode/decode comprehension required attribute #{n}"}
    end
  end

  defmodule XORMappedAddress do
    @moduledoc false

    defmodule IPFamilyError do
      defexception [:message, :number]

      def exception(number: n) do
        %__MODULE__{number: n,
                    message: "IP family should be for 0x01 IPv4 or 0x02 for IPv6" <>
                             " but got 0x#{Integer.to_string(n, 16)}"}
      end
    end

    defmodule LengthError do
      defexception [:message, :length]

      def exception(length: l) do
        %__MODULE__{length: l,
                    message: "Invalid value length. XOR Mapped Address attribute value" <>
          "must be 8 bytes or 20 bytes long for IPv4 and IPv6 respectively"}
      end
    end

    defmodule IPArityError do
      defexception [:message, :family]

      def exception(family: <<0x01::8>>) do
        %__MODULE__{family: <<0x01::8>>,
                    message: "IPv4 addresses are 4 bytes long but got 16 bytes"}
      end
      def exception(family: <<0x02::8>>) do
        %__MODULE__{family: <<0x02::8>>,
                    message: "IPv6 addresses are 16 bytes long but got 4 bytes"}
      end
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
    {:error, HeaderLengthError.exception(binary: bin)}
  end
  def decode(<<header::20-binary, body::binary>>) do
    case Header.decode(%__MODULE__{header: header, body: body}) do
      {:ok, %__MODULE__{body: body, length: length}} when byte_size(body) < length ->
        {:error, BodyLengthError.exception(length: byte_size(body))}
      {:ok, p = %__MODULE__{body: body, length: length}} when byte_size(body) > length ->
        <<trimmed_body::size(length)-bytes, extra::binary>> = body
        Body.decode(%{p | extra: extra, body: trimmed_body})
      {:ok, x} ->
        Body.decode(x)
      {:error, _} = e ->
        e
    end
  end
end
