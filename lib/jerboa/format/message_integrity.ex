defmodule Jerboa.Format.MessageIntegrity do
  @moduledoc false

  alias Jerboa.Params
  alias Jerboa.Format.Body.Attribute.{Username, Realm}

  @hash_length 20
  # lenth of hash (attribute value) plus type and length fields
  @attr_length @hash_length + 4
  @type_code 0x0008

  @spec apply(Params.t, Keyword.t) :: Params.t
  def apply(params, opts) do
    if opts[:with_message_integrity] do
      apply_with_password(params, opts[:password])
    else
      params
    end
  end

  defp apply_with_password(params, password) when is_binary(password) do
    with {:ok, _} <- get_username(params),
         {:ok, _}    <- get_realm(params) do
      hash = calculate_message_integrity(params, password)
      put_message_integrity(params, hash)
    else
      _ -> params
    end
  end
  defp apply_with_password(params, _), do: params

  defp calculate_message_integrity(params, password) do
    {:ok, username} = get_username(params)
    {:ok, realm} = get_realm(params)
    key = calculate_hash_key(username, realm, password)
    data = get_hash_subject(params)
    :crypto.hmac :sha, key, data
  end

  defp calculate_hash_key(username, realm, password) do
    :crypto.hash(:md5, username <> ":" <> realm <> ":" <> password)
  end

  defp get_hash_subject(%Params{header: header, body: body}) do
    modify_length(header) <> body
  end

  defp modify_length(<<0::2, type::14, length::16, rest::binary>>) do
    <<0::2, type::14, (length + @attr_length)::16, rest::binary>>
  end

  defp put_message_integrity(params, hash) do
    message_integrity = <<@type_code::16, @hash_length::16, hash::binary>>
    %{params | header: modify_length(params.header),
               message_integrity: message_integrity}
  end

  defp get_username(params), do: maybe_get_attr(params, Username)

  defp get_realm(params), do: maybe_get_attr(params, Realm)

  defp maybe_get_attr(params, attr) do
    case Params.get_attr(params, attr) do
      nil -> :error
      attr -> {:ok, attr.value}
    end
  end
end
