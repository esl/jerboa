defmodule Jerboa.Test.Helper.Credentials do
  @moduledoc false

  alias Jerboa.Client.Credentials

  @username "alice"
  @realm "wonderlan"
  @nonce "abcd"
  @secret "1234"

  @invalid_nonce "dcba"

  def final do
    %Credentials.Final{username: @username, realm: @realm,
                       nonce: @nonce, secret: @secret}
  end

  def initial do
    %Credentials.Initial{username: @username, secret: @secret}
  end

  def invalid_nonce, do: @invalid_nonce

  def valid_nonce, do: @nonce
end
