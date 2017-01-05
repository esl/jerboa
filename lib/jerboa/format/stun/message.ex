defmodule Jerboa.Format.STUN.Message do
  @moduledoc """
  Data structure representing STUN protocol message
  as defined in [RFC 5389](https://tools.ietf.org/html/rfc5389#section-6)

  Description of fields:
  * `:class` - STUN message class
  * `:method` - STUN message method
  * `:t_id` - transaction ID
  """

  alias Jerboa.Format.STUN.{Bare, Class, Method, DecodeError}

  defstruct [:t_id, :class, :method]

  @type t :: %__MODULE__{
    t_id: non_neg_integer,
    class: Class.t,
    method: Method.name
  }

  @doc false
  @spec from_bare(Bare.t) :: {:ok, t} | {:error, DecodeError.t}
  def from_bare(bare) do
    {message, _bare, errors} =
      {%__MODULE__{}, bare, %DecodeError{}}
      |> put_class()
      |> put_method()
      |> put_transaction_id()
    case  DecodeError.empty?(errors) do
      true  -> {:ok, message}
      false -> {:error, errors}
    end
  end

  defp put_class({message, %{class: class} = bare, errors}) do
    {%{message | class: class}, bare, errors}
  end

  defp put_method({message, %{method: method, class: class} = bare, errors}) do
    decoded_method = Method.decode method
    case {decoded_method, Method.class_allowed?(decoded_method, class)} do
      {nil, _} ->
        {message, bare, %{errors | method: "is unknown"}}
      {_, false} ->
        {message, bare, Map.put(errors, :method,
          "method #{decoded_method} is not allowed with class #{class}")}
      _ ->
        {%{message | method: decoded_method}, bare, errors}
    end
  end

  defp put_transaction_id({message, %{t_id: t_id} = bare, errors}) do
    {%{message | t_id: t_id}, bare, errors}
  end
end
