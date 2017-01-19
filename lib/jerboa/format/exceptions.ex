defmodule Jerboa.Format.HeaderLengthError do
  defexception [:message, :binary]

  def exception(opts) do
    b = opts[:binary]
    %__MODULE__{binary: b,
                message: "the STUN wire format requires a header of at least" <>
                  " 20 bytes but got #{byte_size b} bytes"}
  end
end

defmodule Jerboa.Format.BodyLengthError do
  defexception [:message, :length]

  def exception(opts) do
    %__MODULE__{length: opts[:length],
                message: "message body is shorter than specified length"}
  end
end

defmodule Jerboa.Format.First2BitsError do
  defexception [:message, :bits]

  def exception(opts) do
    %__MODULE__{bits: opts[:bits],
                message: "the most significant two bits of a STUN " <>
                  "message must be zeros"}
  end
end

defmodule Jerboa.Format.MagicCookieError do
  defexception [:message, :header]

  def exception(opts) do
    %__MODULE__{header: opts[:header],
                message: "STUN message doesn't have magic cookie"}
  end
end

defmodule Jerboa.Format.UnknownMethodError do
  defexception [:message, :method]

  def exception(opts) do
    m = opts[:method]
    %__MODULE__{method: m,
                message: "unknown STUN method 0x#{Integer.to_string(m, 16)}"}
  end
end

defmodule Jerboa.Format.Last2BitsError do
  defexception [:message, :length]

  def exception(opts) do
    %__MODULE__{length: opts[:length],
                message: "all STUN attributes are padded to a multiple of 4 bytes" <>
                  " so the last 2 bits of this field should be zero"}
  end
end

defmodule Jerboa.Format.ComprehensionError do
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
    defexception [:message, :number]

    def exception(opts) do
      n = opts[:number]
      %__MODULE__{number: n,
                  message: "IP family should be for 0x01 IPv4 or 0x02 for IPv6" <>
                    " but got 0x#{Integer.to_string(n, 16)}"}
    end
  end

  defmodule LengthError do
    defexception [:message, :length]

    def exception(opts) do
      %__MODULE__{length: opts[:length],
                  message: "Invalid value length. XOR Mapped Address attribute value" <>
                    "must be 8 bytes or 20 bytes long for IPv4 and IPv6 respectively"}
    end
  end

  defmodule IPArityError do
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
