defmodule Jerboa.Test.Helper.Credentials do
  @moduledoc false

  alias Jerboa.Client.Credentials

  @username "alice"
  @realm "wonderlan"
  @nonce "abcd"
  @secret "1234"

  @invalid_nonce "dcba"

  def valid_creds do
    %Credentials{username: @username, realm: @realm,
                 nonce: @nonce, secret: @secret}
  end

  def incomplete_creds do
    valid_creds() |> Map.put(:nonce, nil)
  end

  def invalid_nonce, do: @invalid_nonce

  def valid_nonce, do: @nonce
end
