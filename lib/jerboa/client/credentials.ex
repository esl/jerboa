defmodule Jerboa.Client.Credentials do
  @moduledoc false
  ## Data structure containing client's authentication data

  defstruct [:username, :realm, :secret, :nonce]

  @type t :: %__MODULE__{
    username: String.t | nil,
    realm:    String.t | nil,
    secret:   String.t | nil,
    nonce:    String.t | nil
  }

  @spec to_decode_opts(t) :: Keyword.t
  def to_decode_opts(creds) do
    if complete?(creds) do
      creds |> Map.from_struct() |> Map.to_list()
    else
      []
    end
  end

  @spec complete?(t) :: boolean
  def complete?(creds) do
    creds
    |> Map.from_struct()
    |> Enum.all?(fn {_, v} -> v end)
  end
end
