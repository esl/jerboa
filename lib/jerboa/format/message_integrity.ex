defmodule Jerboa.Format.MessageIntegrity do
  @moduledoc false

  alias Jerboa.Format.Meta
  alias Jerboa.Params
  alias Jerboa.Format.Body.Attribute.Username
  alias Jerboa.Format.Body.Attribute.Realm

  @hash_length 20
  @attr_length @hash_length + 4

  @spec apply(Meta.t) :: Meta.t
  def apply(meta) do
    case assert_required_options(meta) do
      :ok -> apply_message_integrity(meta)
      _   -> meta
    end
  end

  @spec assert_required_options(Meta.t) :: :ok | :error
  defp assert_required_options(meta) do
    with {:ok, _} <- get_username(meta),
         {:ok, _} <- get_secret(meta),
         {:ok, _} <- get_realm(meta) do
      :ok
    end
  end

  @spec get_username(Meta.t) :: {:ok, String.t} | :error
  defp get_username(meta) do
    from_attr = Params.get_attr(meta.params, Username)
    from_opts = meta.options[:username]
    cond do
      from_attr -> {:ok, from_attr.value}
      from_opts -> {:ok, from_opts}
      true      -> :error
    end
  end

  @spec get_secret(Meta.t) :: {:ok, String.t} | :error
  defp get_secret(meta) do
    case meta.options[:secret] do
      nil -> :error
      secret -> {:ok, secret}
    end
  end

  @spec get_realm(Meta.t) :: {:ok, String.t} | :error
  defp get_realm(meta) do
    case Params.get_attr(meta.params, Realm) do
      nil -> :error
      realm -> {:ok, realm.value}
    end
  end

  @spec apply_message_integrity(Meta.t) :: Meta.t
  defp apply_message_integrity(meta) do
    {:ok, username} = get_username(meta)
    {:ok, realm} = get_realm(meta)
    {:ok, secret} = get_secret(meta)
    key = calculate_hash_key(username, realm, secret)
    data = get_hash_subject(meta)
    hash = :crypto.hmac(:sha, key, data)
    %{meta | body: meta.body <> attribute(hash),
             header: modify_header_length(meta.header)}
  end

  @spec calculate_hash_key(String.t, String.t, String.t) :: binary
  defp calculate_hash_key(username, realm, secret) do
    :crypto.hash :md5, [username, ":", realm, ":", secret]
  end

  @spec get_hash_subject(Meta.t) :: iolist
  defp get_hash_subject(%Meta{header: header, body: body}) do
    [modify_header_length(header), body]
  end

  @spec modify_header_length(header :: binary) :: binary
  defp modify_header_length(<<0::2, type::14, length::16, rest::binary>>) do
    <<0::2, type::14, (length + @attr_length)::16, rest::binary>>
  end

  @spec attribute(hash :: binary) :: attribute :: binary
  defp attribute(hash) do
    <<0x0008::16, @hash_length::16, hash::binary>>
  end
end
