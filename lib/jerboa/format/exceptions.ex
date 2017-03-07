defmodule Jerboa.Format.HeaderLengthError do
  @moduledoc """

  Error indicating STUN message with header of invalid length

  STUN messages have a fixed header of 20 bytes, so any message
  shorter than that will produce this error when passed to
  `Jerboa.Format.decode/1`.

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

  Error indicating STUN message with body shorter than that declared
  in header

  Each STUN message contains the length of its body encoded in the
  header. If a message body is shorter than that declared in the
  header it cannot be decoded correctly and will produce this error
  when passed to `Jerboa.Format.decode/1`.

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

  Error indicating wrong value encoded in first two bits of STUN
  message

  A STUN message header must start with two zero (clear) bits. If it
  doesn't this error is produced when decoding the message.

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

  Error indicating that the message does not encode the magic cookie
  value

  The second 4 bytes of each STUN message header have a fixed value of
  `0x2112A442` otherwise the message can't be identified as a STUN
  message and this error is produced.

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

  Error indicating that the STUN message method is unknown to Jerboa

  STUN methods are (along with classes) the primary indicator of how
  messages should be processed. If the method is unknown the STUN
  agent won't know how to service to the message.

  Exception struct fields:

  * `:method` - integer with a value of the unknown method

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

  Error indicating that the last two bits of the STUN message length
  field are not zeroes (clear)

  STUN messages must be padded to a multiple of 4 bytes, so the length
  value encoded in the message header must be a multiple of 4. The
  binary representation of numbers divisible by 4 always have the last
  two bits set to 0. This serves as another distinguishing feature, at
  least, of a correctly formed STUN message.

  Exception struct fields:

  * `:length` - value of the length field in the message header

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

  Error indicating that the STUN message contained a
  comprehension-required attribute unknown to Jerboa

  If the STUN message contains a comprehension-required attribute
  which is unknown to the STUN agent then it cannot be successfully
  processed.

  Exception struct fields:

  * `:attribute` - integer value of the unknown attribute

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

    Error indicating that the IP address family encoded in the
    XOR-MAPPED-ADDRESS attribute's value is invalid

    Valid address families are 0x01 for IPv4 and 0x02 for IPv6.

    Exception struct fields:

    * `:number` - address family number encoded in the attribute's
      value

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

    Error indicating that the XOR-MAPPED-ADDRESS attribute has invalid
    length

    The XOR-MAPPED-ADDRESS attribute is encoded into 8 bytes for IPv4
    and 20 bytes for IPv6.

    Exception struct fields:

    * `:length` - length of attribute's value found in the message

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

    Error indicating that the IP address family and IP address length
    of the XOR-MAPPED-ADDRESS attribute don't make sense

    For example: the IP address family value may be 0x01 (IPv4) while
    the length of an address is 16 bytes, as in IPv6.

    Exception struct fields:

    * `:family` - the IP address family given in the
      XOR-MAPPED-ADDRESS attribute (either `<<0x01>>` or `<<0x02>>`)

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

defmodule Jerboa.Format.Lifetime do
  @moduledoc false

  defmodule LengthError do
    @moduledoc """
    Error indicating that LIFETIME attribute's value has invalid
    length

    TURN RFC requires that LIFETIME attribute's value must be 4 bytes long
    so any other length results in this error.

    Exception struct fields:
    * `:length` - length of attribute's value found in STUN message (in bytes)
    """

    defexception [:message, :length]

    def exception(opts) do
      length = opts[:length]
      %__MODULE__{length: length,
                  message: "Invalid value length. LIFETIME attribute's value must be " <>
                    "4 bytes long (found #{length})"}
    end
  end
end

defmodule Jerboa.Format.Nonce.LengthError do
  @moduledoc """
  Error indicating that NONCE attribute's value has invalid
  length

  STUN RFC requires that NONCE attribute's value must be maximum 128 UTF-8 encoded
  characters long, so any longer value results in this error.

  Exception struct fields:
  * `:length` - length of attribute's value found in STUN message (number of UTF-8 encoded characters)
  """

  defexception [:message, :length]

  def exception(opts) do
    length = opts[:length]
    %__MODULE__{length: length,
                message: "Invalid value length. NONCE attribute's value must be " <>
                  "maximum 128 characters long (found #{length})"}
  end
end

defmodule Jerboa.Format.Username.LengthError do
  @moduledoc """
  Error indicating that USERNAME attribute's value has invalid
  length

  STUN RFC requires that USERNAME attribute's value must be a valid UTF-8 encoded
  sequence of 512 or less bytes.

  Exception struct fields:
  * `:length` - length of attribute's value found in STUN message (in bytes)
  """

  defexception [:message, :length]

  def exception(opts) do
    length = opts[:length]
    %__MODULE__{length: length,
                message: "Invalid value length. USERNAME attribute's value must be " <>
                  "maximum 512 bytes long (found #{length})"}
  end
end

defmodule Jerboa.Format.Realm.LengthError do
  @moduledoc """
  Error indicating that REALM attribute's value has invalid
  length

  STUN RFC requires that REALM attribute's value must be maximum 128 UTF-8 encoded
  characters long, so any longer value results in this error.

  Exception struct fields:
  * `:length` - length of attribute's value found in STUN message (number of UTF-8 encoded characters)
  """

  defexception [:message, :length]

  def exception(opts) do
    length = opts[:length]
    %__MODULE__{length: length,
                message: "Invalid value length. REALM attribute's value must be " <>
                  "maximum 128 characters long (found #{length})"}
  end
end

defmodule Jerboa.Format.ErrorCode.FormatError do
  @moduledoc """
  Error indicating invalid format of ERROR-CODE attribute

  STUN RFC and its extensions define several error code values which must be known
  by STUN agent. In addition reason field of ERROR-CODE must be valid UTF-8
  encoded string, no longer than 128 characters. This error indicates breaking of any
  of these constraints.

  You may also encounter this error when ERROR-CODE attribute's binary format isn't
  compliant with the one specified in STUN RFC.
  """

  defexception [:message, :code, :reason]

  def exception(opts) do
    code = opts[:code]
    reason = opts[:reason]
    %__MODULE__{code: code,
                reason: reason,
                message: "Invalid format ERROR-CODE attribute. Please refer to " <>
                  "documentation of `Jerboa.Format.ErrorCode.FormatError` module for " <>
                  "more information"}
  end
end

defmodule Jerboa.Format.ErrorCode.LengthError do
  @moduledoc """
  Error indicating that ERROR-CODE attribute's value is too short

  ERROR-CODE binary format requires that its value is at least 4 bytes long. Any other
  length results in this error.

  Exception struct fields:
  * `:length` - length of attribute's value found in STUN message (in bytes)
  """

  defexception [:message, :length]

  def exception(opts) do
    length = opts[:length]
    %__MODULE__{length: length,
                message: "Invalid value length. ERROR-CODE attribute's value must be " <>
                  "at least 4 bytes long (found #{length})"}
  end
end
