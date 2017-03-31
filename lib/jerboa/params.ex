defmodule Jerboa.Params do
  @moduledoc """
  Data structure representing STUN message parameters
  """

  alias Jerboa.Format.Header.Type.{Class, Method}
  alias Jerboa.Format.Body.Attribute

  defstruct [:class, :method, :identifier, attributes: [],
             signed?: false, verified?: false]

  @typedoc """
  The main data structure representing STUN message parameters

  The following fields coresspond to the those described in the [STUN
  RFC](https://tools.ietf.org/html/rfc5389#section-6):

  * `class` is one of request, success or failure response, or indincation
  * `method` is a STUN (or TURN) message method described in one of the respective RFCs
  * `identifier` is a unique transaction identifier
  * `attributes` is a list of STUN (or TURN) attributes as described in their
  respective RFCs
  * `signed?` indicates wheter STUN message was signed with MESSAGE-INTEGRITY
    attribute - it isn't important when encoding a message
  * `verified?` - indicates wheter MESSAGE-INTEGRIY from STUN message was
    successfully verified. Same as `signed?`, it's only relevant when decoding
    messages. Note that messages which are `verified?` are also `signed?`, but not
    the other way around.
  """
  @type t :: %__MODULE__{
    class: Class.t,
    method: Method.t,
    identifier: binary,
    attributes: [Attribute.t],
    signed?: boolean,
    verified?: boolean
  }

  @doc """
  Returns params struct with filled in transaction id
  """
  @spec new :: t
  def new do
    %__MODULE__{identifier: generate_id()}
  end

  @doc """
  Sets STUN class in params struct
  """
  @spec put_class(t, Class.t) :: t
  def put_class(params, class) do
    %{params | class: class}
  end

  @doc """
  Retrieves class field from params struct
  """
  @spec get_class(t) :: Class.t | nil
  def get_class(%__MODULE__{class: class}), do: class

  @doc """
  Sets STUN method in params struct
  """
  @spec put_method(t, Method.t) :: t
  def put_method(params, method) do
    %{params | method: method}
  end

  @doc """
  Retrieves method field from params struct
  """
  @spec get_method(t) :: Method.t | nil
  def get_method(%__MODULE__{method: method}), do: method

  @doc """
  Sets STUN transaction identifier in params struct
  """
  @spec put_id(t, binary) :: t
  def put_id(params, id) do
    %{params | identifier: id}
  end

  @doc """
  Retrieves transaction ID from params struct
  """
  @spec get_id(t) :: binary | nil
  def get_id(%__MODULE__{identifier: id}), do: id

  @doc """
  Retrieves all attributes from params struct
  """
  @spec get_attrs(t) :: [Attribute.t]
  def get_attrs(%__MODULE__{attributes: attrs}), do: attrs

  @doc """
  Sets whole attributes list in params struct
  """
  @spec put_attrs(t, [Attribute.t]) :: t
  def put_attrs(params, attrs) do
    %{params | attributes: attrs}
  end

  @doc """
  Retrieves single attribute from params struct

  Returns `nil` if attribute is not present.
  """
  @spec get_attr(t, attr_name :: module) :: Attribute.t
  def get_attr(params, attr_name) do
    params.attributes
    |> Enum.find(fn a -> Attribute.name(a) === attr_name end)
  end

  @doc """
  Puts single attribute in params struct

  If given attribute was already present, it will be overriden, so
  that there are no duplicates.
  """
  @spec put_attr(t, Attribute.t) :: t
  def put_attr(params, attr) do
    attrs =
      params.attributes
      |> Enum.reject(fn a -> Attribute.name(a) === Attribute.name(attr) end)
    %{params | attributes: [attr | attrs]}
  end

  @doc """
  Generates STUN transaction ID
  """
  @spec generate_id :: binary
  def generate_id do
    :crypto.strong_rand_bytes(12)
  end
end
