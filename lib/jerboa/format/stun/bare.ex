defmodule Jerboa.Format.STUN.Bare do
  @moduledoc false

  alias Jerboa.Format.STUN

  defstruct [:t_id, :class, :method, attrs: [], raw: <<>>]

  @stun_magic STUN.magic

  @type bare_attr :: {type :: non_neg_integer, value :: binary}

  @type t :: %__MODULE__{
      t_id: non_neg_integer,
     class: STUN.class,
    method: non_neg_integer,
     attrs: [bare_attr],
       raw: binary
  }

  @spec decode(packet :: binary) :: {:ok, t} | {:error, reason :: term}
  def decode(packet) do
    with {:ok, header} <- validate_header_length(packet),
                   :ok <- validate_first_two_bits(header),
                   :ok <- validate_stun_magic(header),
                  t_id <- extract_transaction_id(header),
                  type <- extract_stun_type(header),
                 class <- decode_message_class(type),
                method <- extract_message_method(type),
     {:ok, body, rest} <- validate_body_length(packet),
          {:ok, attrs} <- extract_attributes(body) do
      struct = %__MODULE__{
        t_id: t_id,
        class: class,
        method: method,
        attrs: Enum.reverse(attrs),
        raw: packet
      }
      {:ok, struct}
    else
      {:error, _reason} = error ->
        error
    end
  end

  defp validate_header_length(<<header::20-binary, _rest::bitstring>>) do
    {:ok, header}
  end
  defp validate_header_length(_), do: {:error, "Invalid header length"}

  defp validate_first_two_bits(<<0::2, _rest::bitstring>>), do: :ok
  defp validate_first_two_bits(_) do
    {:error, "First two bits of STUN packet should be zeroed"}
  end

  defp validate_stun_magic(<<_::32, @stun_magic::32, _::binary>>), do: :ok
  defp validate_stun_magic(_), do: {:error, "Invalid STUN magic cookie"}

  defp extract_transaction_id(<<_::8-binary, t_id::96>>), do: t_id

  defp extract_stun_type(<<_::2, type::14-bitstring, _rest::bitstring>>) do
    type
  end

  defp decode_message_class(<<_::5, c1::1, _::3, c0::1, _::4>>) do
    <<class::2>> = <<c1::1, c0::1>>
    STUN.class_from_integer(class)
  end

  defp extract_message_method(<<m2::5, _::1, m1::3, _::1, m0::4>>) do
    <<method::12>> = <<m2::5, m1::3, m0::4>>
    method
  end

  defp validate_body_length(<<_::16, length::16, _::128,
                              body::size(length)-binary, rest::bitstring>>) do
    {:ok, body, rest}
  end
  defp validate_body_length(_), do: {:error, "Invalid message body length"}

  defp extract_attributes(body, acc \\ [])
  defp extract_attributes(<<>>, acc), do: {:ok, acc}
  defp extract_attributes(body, acc) do
    with {:ok, type, length, val_and_rest} <- extract_attr_type_and_length(body),
                {:ok, value, pad_and_rest} <- extract_attr_value(length, val_and_rest),
                               {:ok, rest} <- trim_padding(pad_and_rest, length) do
      extract_attributes(rest, [{type, value} | acc])
    else
      {:error, _reason} = error ->
        error
    end
  end

  defp extract_attr_type_and_length(<<type::16, length::16, rest::binary>>) do
    {:ok, type, length, rest}
  end
  defp extract_attr_type_and_length(_) do
    {:error, "Not enough bytes for attribute"}
  end

  defp extract_attr_value(length, body) do
    case body do
      <<value::size(length)-binary, rest::binary>> ->
        {:ok, value, rest}
      _ ->
        {:error, "Not enough bytes for attribute value"}
    end
  end

  defp trim_padding(body, length) do
    pad_len = calculate_padding(length)
    case body do
      <<_::size(pad_len)-binary, rest::binary>> ->
        {:ok, rest}
      _ ->
        {:error, "No attribute padding"}
    end
  end

  defp calculate_padding(length) do
    case rem(length, 4) do
      0 -> 0
      n -> 4 - n
    end
  end
end
