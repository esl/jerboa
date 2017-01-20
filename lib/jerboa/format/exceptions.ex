defmodule Jerboa.Format.HeaderLengthError do
  @moduledoc """
  Error indicating STUN message with header of invalid length

  STUN messages have fixed header of 20 bytes, so any message shorter
  than that will produce this error when passed to `Jerboa.Format.decode/1`.

  Exception struct fields:
  * `:binary` - whole STUN message which produced this error
  """

  defexception [:message, :binary]

  def exception(opts) do
    b = opts[:binary]
    %__MODULE__{binary: b,
                message: "the STUN wire format requires a header of at least" <>
                  " 20 bytes but got #{byte_size b} bytes"}
  end
end

defmodule Jerboa.Format.BodyLengthError do
  @moduledoc """
  Error indicating STUN message with body shorter than declared in header

  Each STUN message contains length of its body encoded in a header.
  If a message body is shorter than declared in header it cannot be
  decoded correctly and will produce this error when passed to `Jerboa.Format.decode/1`

  Excepton struct fields:
  * `:length` - actual length of message body
  """

  defexception [:message, :length]

  def exception(opts) do
    %__MODULE__{length: opts[:length],
                message: "message body is shorter than specified length"}
  end
end

defmodule Jerboa.Format.First2BitsError do
  @moduledoc """
  Error indicating wrong value encoded in first to bits of STUN message

  STUN message header must start with two zeroed bits. If it doesn't,
  this error is produced when decoding the message.

  Exception struct fields:
  * `:bits` - a 2 bit long bitstring with the value of first two bits
  of a message
  """

  defexception [:message, :bits]

  def exception(opts) do
    %__MODULE__{bits: opts[:bits],
                message: "the most significant two bits of a STUN " <>
                  "message must be zeros"}
  end
end

defmodule Jerboa.Format.MagicCookieError do
  @moduledoc """
  Error indicating that STUN magic cookie does not have magic cookie value

  Second 4 bytes of each STUN message header must have fixed value of
  `0x2112A442`. If not, the binary can't be indetified as STUN message
  and this error is produced.

  Exception struct fields:
  * `:header` - whole 20 byte header of invalid message
  """

  defexception [:message, :header]

  def exception(opts) do
    %__MODULE__{header: opts[:header],
                message: "STUN message doesn't have magic cookie"}
  end
end

defmodule Jerboa.Format.UnknownMethodError do
  @moduledoc """
  Error indicating that STUN message method is unknown to Jerboa

  STUN methods are (along with classes) a primary indicators of
  how message should be processed. If the method is unknown,
  STUN agent won't know how to react to the message.

  Exception struct fields:
  * `:method` - integer with a value of unknown method
  """

  defexception [:message, :method]

  def exception(opts) do
    m = opts[:method]
    %__MODULE__{method: m,
                message: "unknown STUN method 0x#{Integer.to_string(m, 16)}"}
  end
end

defmodule Jerboa.Format.Last2BitsError do
  @moduledoc """
  Error indicating that last two bits of STUN message length field are
  not zeroes

  STUN messages must be padded to a multiple of 4 bytes, so length field
  encoded in message header must be a multiple of 4. Binary representation
  of numbers divisible by 4 always always have last two bits set to 0.

  Exception struct fields:
  * `:length` - value of length field in message header
  """

  defexception [:message, :length]

  def exception(opts) do
    %__MODULE__{length: opts[:length],
                message: "all STUN attributes are padded to a multiple of 4 bytes" <>
                  " so the last 2 bits of this field should be zero"}
  end
end

defmodule Jerboa.Format.ComprehensionError do
  @moduledoc """
  Error indicating that STUN message contained comprehension-required
  attribute unknown to Jerboa

  If STUN message contains unknown comprehension-required attribute
  it cannot be successfully processed by a STUN agent.

  Exception struct fields:
  * `:attribute` - integer with a value of unknown attribute
  """

  defexception [:message, :attribute]

  def exception(opts) do
    a = opts[:attribute]
    %__MODULE__{attribute: a,
                message: "can not encode/decode comprehension required attribute #{a}"}
  end
end

defmodule Jerboa.Format.XORMappedAddress do
  @moduledoc false

  defmodule IPFamilyError do
    @moduledoc """
    Error indicating that address family encoded in XOR-MAPPED-ADDRESS
    attribute's value is invalid

    Valid address families are 0x01 for IPv4 and 0x02 for IPv6.

    Exception struct fields:
    * `:number` - address family number encoded in attribute's value
    """

    defexception [:message, :number]

    def exception(opts) do
      n = opts[:number]
      %__MODULE__{number: n,
                  message: "IP family should be for 0x01 IPv4 or 0x02 for IPv6" <>
                    " but got 0x#{Integer.to_string(n, 16)}"}
    end
  end

  defmodule LengthError do
    @moduledoc """
    Error indicating that XOR-MAPPED-ADDRESS attribute's value has
    invalid length

    Possible length of XOR-MAPPED-ADDRESS are 8 bytes for IPv4
    and 20 bytes for IPv6.

    Exception struct fields:
    * `:length` - length of attribute's value found in a message
    """

    defexception [:message, :length]

    def exception(opts) do
      %__MODULE__{length: opts[:length],
                  message: "Invalid value length. XOR Mapped Address attribute value" <>
                    "must be 8 bytes or 20 bytes long for IPv4 and IPv6 respectively"}
    end
  end

  defmodule IPArityError do
    @moduledoc """
    Error indicating that address family and IP address of
    XOR-MAPPED-ADDRESS are not matching

    For example, address family value is 0x01 (IPv4) while length
    of an address is 16 bytes, as in IPv6.

    Exception struct fields:
    * `:family` - binary with a value of address family of XOR-MAPPED-ADDRESS
    (either `<<0x01>>` or `<<0x02>>`)
    """

    defexception [:message, :family]

    def exception(opts) do
      message =
        case opts[:family] do
          <<0x01::8>> ->
            "IPv4 addresses are 4 bytes long but got 16 bytes"
          <<0x02::8>> ->
            "IPv6 addresses are 16 bytes long but got 4 bytes"
        end
      %__MODULE__{family: opts[:family],
                  message: message}
    end
  end
end
