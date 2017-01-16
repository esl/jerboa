defmodule Jerboa.Format.Header.Type do
  @moduledoc false
  alias Jerboa.Format.UnknownMethodError

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
    def encode(:binding), do: <<0x0001::12>>

    @doc false
    def decode(<<0x0001::12>>), do: {:ok, :binding}
    def decode(<<m::12>>),      do: {:error, UnknownMethodError.exception(method: m)}
  end

  def encode(%Jerboa.Format{class: x, method: y}) do
    encode Class.encode(x), Method.encode(y)
  end

  def decode(<<m0_4::5-bits, c0::1, m5_7::3-bits, c1::1, m7_10::4-bits>>) do
    case Method.decode(<<m0_4::5-bits, m5_7::3-bits, m7_10::4-bits>>) do
      {:ok, method} ->
        class = Class.decode(<<c0::1, c1::1>>)
        {:ok, class, method}
      {:error, _} = e ->
        e
    end
  end

  defp encode(<<c0::1, c1::1 >>, << m0_3::4, m4_6::3, m7_11::5>>) do
    <<m0_3::4, c0::1, m4_6::3, c1::1, m7_11::5>>
  end
end
