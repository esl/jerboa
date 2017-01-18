defmodule Jerboa.Format.HeaderLengthError do
  defexception [:message, :binary]

  def exception(binary: b) do
    %__MODULE__{binary: b,
                message: "the STUN wire format requires a header of at least" <>
                  " 20 bytes but got #{byte_size b} bytes"}
  end
end

defmodule Jerboa.Format.BodyLengthError do
  defexception [:message, :length]

  def exception(length: l) do
    %__MODULE__{length: l,
                message: "message body is shorter than specified length"}
  end
end

defmodule Jerboa.Format.First2BitsError do
  defexception [:message, :bits]

  def exception(bits: b) do
    %__MODULE__{bits: b,
                message: "the most significant two bits of a STUN " <>
                  "message must be zeros"}
  end
end

defmodule Jerboa.Format.MagicCookieError do
  defexception [:message, :header]

  def exception(header: h) do
    %__MODULE__{header: h,
                message: "STUN message doesn't have magic cookie"}
  end
end

defmodule Jerboa.Format.UnknownMethodError do
  defexception [:message, :method]

  def exception(method: m) do
    %__MODULE__{method: m,
                message: "unknown STUN method 0x#{Integer.to_string(m, 16)}"}
  end
end

defmodule Jerboa.Format.Last2BitsError do
  defexception [:message, :length]

  def exception(length: l) do
    %__MODULE__{length: l,
                message: "all STUN attributes are padded to a multiple of 4 bytes" <>
                  " so the last 2 bits of this field should be zero"}
  end
end

defmodule Jerboa.Format.ComprehensionError do
  defexception [:message, :attribute]

  def exception(attribute: n) do
    %__MODULE__{attribute: n,
                message: "can not encode/decode comprehension required attribute #{n}"}
  end
end

defmodule Jerboa.Format.XORMappedAddress do
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
