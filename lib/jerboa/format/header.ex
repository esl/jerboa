defmodule Jerboa.Format.Header do
  @moduledoc false

  alias Jerboa.Format.Header.{Type,Length,MagicCookie,Identifier}
  alias Jerboa.Format.Meta

  @magic_cookie MagicCookie.encode

  @spec encode(Meta.t) :: Meta.t
  def encode(meta) do
    type = Type.encode(meta)
    length = Length.encode(meta)
    id = Identifier.encode(meta)
    %{meta | header: encode(type, length, id)}
  end

  defp encode(type, length, identifier) do
    <<0::2, type::bits, length::bytes, @magic_cookie::bytes, identifier::bytes>>
  end

  @spec decode(Meta.t) :: {:ok, Meta.t} | {:error, struct}
  def decode(%Meta{header: header, params: params} = meta) do
    with {:ok, t, l, id}      <- destructure_header(header),
         {:ok, class, method} <- Type.decode(t),
         {:ok, length}        <- Length.decode(l) do
      new_params = %{params | class: class, method: method, identifier: id}
      new_meta = %{meta | length: length, params: new_params}
      {:ok, new_meta}
    else
      {:error, _} = e ->
        e
    end
  end

  defp destructure_header(<<0::2, t::14-bits, l::16-bits,
    @magic_cookie::bytes, id::96-bits>>) do
    {:ok, t, l, id}
  end
  defp destructure_header(<<0::2, _::30, _::128>> = header) do
    {:error, Jerboa.Format.MagicCookieError.exception(header: header)}
  end
  defp destructure_header(<<b::2, _::158>>) do
    {:error, Jerboa.Format.First2BitsError.exception(bits: b)}
  end
end
