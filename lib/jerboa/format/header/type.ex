defmodule Jerboa.Format.Header.Type do
  @moduledoc false

  alias Jerboa.Format.UnknownMethodError
  alias Jerboa.Params

  defmodule Class do
    @moduledoc """
    The STUN message classes
    """

    @typedoc """
    Either a request, indication, success or failure response
    """
    @type t :: :request | :indication | :success | :failure

    @doc false
    def encode(:request),    do: <<0::2>>
    def encode(:indication), do: <<1::2>>
    def encode(:success),    do: <<2::2>>
    def encode(:failure),    do: <<3::2>>

    @doc false
    def decode(<<0::2>>), do: :request
    def decode(<<1::2>>), do: :indication
    def decode(<<2::2>>), do: :success
    def decode(<<3::2>>), do: :failure
  end

  defmodule Method do
    @moduledoc """
    The STUN message methods
    """

    @typedoc """
    The atom representing a STUN method
    """
    @type t :: :binding

    @doc false
    def encode(:binding), do: <<0x001::12>>

    @doc false
    def decode(<<0x001::12>>), do: {:ok, :binding}
    def decode(<<m::12>>),     do: {:error, UnknownMethodError.exception(method: m)}
  end

  def encode(%Params{class: x, method: y}) do
    encode Class.encode(x), Method.encode(y)
  end

  def decode(<<m11_7::5-bits, c1::1, m6_4::3-bits, c0::1, m3_0::4-bits>>) do
    case Method.decode(<<m11_7::5-bits, m6_4::3-bits, m3_0::4-bits>>) do
      {:ok, method} ->
        class = Class.decode(<<c1::1, c0::1>>)
        {:ok, class, method}
      {:error, _} = e ->
        e
    end
  end

  defp encode(<<c1::1, c0::1 >>, <<m11_7::5, m6_4::3, m3_0::4>>) do
    <<m11_7::5, c1::1, m6_4::3, c0::1, m3_0::4>>
  end
end
