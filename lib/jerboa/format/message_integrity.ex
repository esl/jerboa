defmodule Jerboa.Format.MessageIntegrity do
  @moduledoc false

  alias Jerboa.Format.Meta
  alias Jerboa.Params
  alias Jerboa.Format.Body.Attribute.Username
  alias Jerboa.Format.Body.Attribute.Realm
  alias Jerboa.Format.MessageIntegrity.{FormatError, UsernameMissingError,
                                        RealmMissingError, SecretMissingError,
                                        VerificationError}

  @type_code 0x0008
  @hash_length 20
  @attr_length @hash_length + 4

  def type_code, do: @type_code

  @spec extract(Meta.t, binary) :: {:ok, Meta.t} | {:error, struct}
  def extract(meta, <<@type_code::16, @hash_length::16,
    hash::@hash_length-binary, _::binary>>) do
    {:ok, %{meta | message_integrity: hash}}
  end
  def extract(_, _) do
    {:error, FormatError.exception()}
  end

  @spec apply(Meta.t) :: Meta.t
  def apply(meta) do
    case assert_required_options(meta) do
      :ok -> apply_message_integrity(meta)
      _   -> meta
    end
  end

  @spec verify(Meta.t) :: {:ok, Meta.t} | {:error, struct}
  def verify(meta) do
    with true <- has_message_integrity?(meta),
         :ok <- assert_required_options(meta),
         :ok <- verify_message_integrity(meta) do
      {:ok, meta}
    else
      false -> {:ok, meta}
      {:error, _} = error -> error
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

  @spec get_username(Meta.t) :: {:ok, String.t} | {:error, struct}
  defp get_username(meta) do
    from_attr = Params.get_attr(meta.params, Username)
    from_opts = meta.options[:username]
    cond do
      from_attr -> {:ok, from_attr.value}
      from_opts -> {:ok, from_opts}
      true      -> {:error, UsernameMissingError.exception()}
    end
  end

  @spec get_secret(Meta.t) :: {:ok, String.t} | {:error, struct}
  defp get_secret(meta) do
    case meta.options[:secret] do
      nil -> {:error, SecretMissingError.exception()}
      secret -> {:ok, secret}
    end
  end

  @spec get_realm(Meta.t) :: {:ok, String.t} | {:error, struct}
  defp get_realm(meta) do
    from_attr = Params.get_attr(meta.params, Realm)
    from_opts = meta.options[:realm]
    cond do
      from_attr -> {:ok, from_attr.value}
      from_opts -> {:ok, from_opts}
      true      -> {:error, RealmMissingError.exception()}
    end
  end

  @spec apply_message_integrity(Meta.t) :: Meta.t
  defp apply_message_integrity(meta) do
    key = calculate_hash_key(meta)
    data = get_hash_subject(meta)
    hash = calculate_hash(key, data)
    %{meta | body: meta.body <> attribute(hash),
             header: modify_header_length(meta.header)}
  end

  @spec has_message_integrity?(Meta.t) :: boolean
  defp has_message_integrity?(meta) do
    case meta.message_integrity do
      <<>> -> false
      _ -> true
    end
  end

  @spec verify_message_integrity(Meta.t) :: :ok | {:error, struct}
  defp verify_message_integrity(meta) do
    key = calculate_hash_key(meta)
    data = meta |> amend_header_and_body() |> get_hash_subject()
    hash = calculate_hash(key, data)
    if hash == meta.message_integrity do
      :ok
    else
      {:error, VerificationError.exception()}
    end
  end

  @spec calculate_hash_key(Meta.t) :: binary
  defp calculate_hash_key(meta) do
    {:ok, username} = get_username(meta)
    {:ok, realm} = get_realm(meta)
    {:ok, secret} = get_secret(meta)
    :crypto.hash :md5, [username, ":", realm, ":", secret]
  end

  @spec calculate_hash(binary, binary) :: binary
  def calculate_hash(key, data) do
    :crypto.hmac(:sha, key, data)
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
    <<@type_code::16, @hash_length::16, hash::binary>>
  end

  @spec amend_header_and_body(Meta.t) :: Meta.t
  defp amend_header_and_body(meta) do
    length = meta.length_up_to_integrity

    <<0::2, type::14, _::16, header_rest::binary>> = meta.header
    amended_header = <<0::2, type::14, length::16, header_rest::binary>>

    <<amended_body::size(length)-bytes, _::binary>> = meta.body

    %{meta | body: amended_body, header: amended_header}
  end
end
