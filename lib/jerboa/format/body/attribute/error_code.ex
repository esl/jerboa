defmodule Jerboa.Format.Body.Attribute.ErrorCode do
  @moduledoc """
  ERROR-CODE attribute as defined in [STUN RFC](https://tools.ietf.org/html/rfc5389#section-15.6)
  """

  alias Jerboa.Format.Body.Attribute.{Decoder,Encoder}
  alias Jerboa.Format.ErrorCode.{FormatError, LengthError}
  alias Jerboa.Params

  defstruct [:code, :name, reason: ""]

  @typedoc """
  Represents error code of error response

  Struct fields
  * `:code` - integer representation of an error
  * `:name` - atom representation of an error
  * `:reason`
  """
  @type t :: %__MODULE__{
    code: code,
    name: name,
    reason: String.t
  }

  @type code :: 300 | 400 | 401 | 420 | 438 | 500
              | 403 | 437 | 441 | 442 | 486 | 508

  @type name :: :try_alternate
              | :bad_request
              | :unauthorized
              | :unknown_attribute
              | :stale_nonce
              | :server_error
              | :forbidden
              | :allocation_mismatch
              | :wrong_credentials
              | :unsupported_protocol
              | :allocation_quota_reached
              | :insufficient_capacity

  @valid_codes [300, 400, 401, 420, 438, 500,
                403, 437, 441, 442, 486, 508]

  @valid_names [:try_alternate,
                :bad_request,
                :unauthorized,
                :unknown_attribute,
                :stale_nonce,
                :server_error,
                :forbidden,
                :allocation_mismatch,
                :wrong_credentials,
                :unsupported_protocol,
                :allocation_quota_reached,
                :insufficient_capacity]

  @max_reason_length 128

  defimpl Encoder do
    alias Jerboa.Format.Body.Attribute.ErrorCode
    @type_code 0x0009

    @spec type_code(ErrorCode.t) :: integer
    def type_code(_), do: @type_code

    @spec encode(ErrorCode.t, Params.t) :: binary
    def encode(attr, _), do: ErrorCode.encode(attr)
  end

  defimpl Decoder do
    alias Jerboa.Format.Body.Attribute.ErrorCode

    @spec decode(ErrorCode.t, value :: binary, Params.t)
      :: {:ok, ErrorCode.t} | {:error, struct}
    def decode(_, value, _), do: ErrorCode.decode(value)
  end

  @doc false
  def encode(%__MODULE__{code: code, name: name, reason: reason}) do
    error_code = code || name_to_code(name)
    if code_valid?(error_code) do
      encode(error_code, reason)
    else
      raise ArgumentError, "invalid or missing error code or name " <>
        "while encoding ERROR-CODE attribute"
    end
  end

  defp encode(error_code, reason) do
    if reason_valid?(reason) do
      error_class = div error_code, 100
      error_number = rem error_code, 100
      <<0::21, error_class::3, error_number::8>> <> reason
    else
      raise ArgumentError, "ERROR-CODE reason must be UTF-8 encoded binary"
    end
  end

  @doc false
  def decode(<<0::21, error_class::3, error_number::8, reason::binary>>) do
    code = code(error_class, error_number)
    if reason_valid?(reason) && code_valid?(code) do
      {:ok, %__MODULE__{
          code: code,
          name: code_to_name(code),
          reason: reason
       }}
    else
        {:error, FormatError.exception(code: code,
            reason: reason)}
    end
  end
  def decode(bin) do
    {:error, LengthError.exception(length: byte_size(bin))}
  end

  for {code, name} <- List.zip([@valid_codes, @valid_names]) do
    defp code_to_name(unquote(code)), do: unquote(name)
    defp name_to_code(unquote(name)), do: unquote(code)
    defp code_valid?(unquote(code)), do: true
  end

  defp code_to_name(_), do: :error
  defp name_to_code(_), do: :error
  defp code_valid?(_), do: false

  defp reason_valid?(reason) do
    String.valid?(reason) && String.length(reason) <= @max_reason_length
  end

  defp code(class, number), do: class * 100 + number

  @doc false
  def max_reason_length, do: @max_reason_length

  @doc false
  def valid_codes, do: @valid_codes

  @doc false
  def valid_names, do: @valid_names

end
