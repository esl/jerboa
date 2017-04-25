defmodule Jerboa.Client.Credentials do
  @moduledoc false
  ## Data structures containing client's authentication data

  defstruct [:username, :realm, :secret, :nonce]

  @type t :: __MODULE__.Initial.t | __MODULE__.Final.t

  defmodule Initial do
    @moduledoc false

    defstruct [:username, :secret]

    @type t :: %__MODULE__{
      username: String.t,
      secret:   String.t
    }
  end

  defmodule Final do
    @moduledoc false

    defstruct [:username, :secret, :realm, :nonce]

    @type t :: %__MODULE__{
      username: String.t,
      secret:   String.t,
      realm:    String.t,
      nonce:    String.t
    }
  end

  @spec initial(String.t, String.t) :: __MODULE__.Initial.t
  def initial(username, secret)
    when is_binary(username) and is_binary(secret) do
    %Initial{username: username, secret: secret}
  end

  @spec finalize(__MODULE__.Initial.t, String.t, String.t) :: __MODULE__.Final.t
  def finalize(%Initial{} = creds, realm, nonce)
    when is_binary(realm) and is_binary(nonce) do
    %Final{
      username: creds.username,
      secret: creds.secret,
      realm: realm,
      nonce: nonce
    }
  end

  @spec to_decode_opts(t) :: Keyword.t
  def to_decode_opts(%Initial{}), do: []
  def to_decode_opts(%Final{} = creds) do
    creds |> Map.from_struct() |> Map.to_list()
  end

  @spec complete?(t) :: boolean
  def complete?(%Initial{}), do: false
  def complete?(%Final{}), do: true
end
