defmodule Jerboa.Test.Helper.Params do
  @moduledoc false

  alias Jerboa.Params
  alias Jerboa.Format.Body.Attribute.{Username, Realm, Nonce}

  def username(params) do
    case Params.get_attr(params, Username) do
      %{value: u} -> u
      nil -> nil
    end
  end

  def realm(params) do
    case Params.get_attr(params, Realm) do
      %{value: r} -> r
      nil -> nil
    end
  end

  def nonce(params) do
    case Params.get_attr(params, Nonce) do
      %{value: n} -> n
      nil -> nil
    end
  end
end
