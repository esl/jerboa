defmodule Jerboa.Format.STUN.Message do
  @moduledoc """
  Data structure representing STUN protocol message
  as defined in [RFC 5389](https://tools.ietf.org/html/rfc5389#section-6)

  Description of fields:
  * `:class` - STUN message class
  * `:t_id` - transaction ID
  """

  alias Jerboa.Format.STUN.{Bare, Class}

  defstruct [:t_id, :class]

  @type t :: %__MODULE__{
    t_id: non_neg_integer,
    class: Class.t
  }

  ## This function should be called with valid,
  ## decoded %Bare{} struct
  @doc false
  @spec from_bare(Bare.t) :: {:ok, t}
  def from_bare(bare) do
    struct =
      %__MODULE__{
        t_id: bare.t_id,
        class: bare.class
      }
    {:ok, struct}
  end
end
