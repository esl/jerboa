defmodule Jerboa.Format.Head.Type do
  @moduledoc false

  defmodule Class do
    @moduledoc """
    The STUN message classes
    """

    @typedoc """
    Either a request, indication, success or failure response
    """
    @type t :: :request | :indication | :success | :failure

    @doc false
    def encode(:request),    do: <<0 :: 2>>
    def encode(:indication), do: <<1 :: 2>>
    def encode(:success),    do: <<2 :: 2>>
    def encode(:failure),    do: <<3 :: 2>>

    @doc false
    def decode(<<0 :: 2>>), do: :request
    def decode(<<1 :: 2>>), do: :indication
    def decode(<<2 :: 2>>), do: :success
    def decode(<<3 :: 2>>), do: :failure
  end

  defmodule Method do
    @moduledoc """
    The STUN message methods
    """

    defmodule UnknownError do
      defexception [:message,:method]

      def message(%__MODULE__{method: m}) do
        "unknown STUN method 0x#{Integer.to_string(m, 16)}"
      end
    end

    @typedoc """
    The atom representing a STUN method
    """
    @type t :: :binding

    @doc false
    def encode(:binding), do: <<0x0001 :: 12>>

    @doc false
    def decode(<<0x0001 :: 12>>), do: {:ok, :binding}
    def decode(<<m :: 12>>),      do: {:error, UnknownError.exception(method: m)}
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

  defp encode(<< c0::1, c1::1 >>, << m0::1, m1::1, m2::1, m3::1, m4::1, m5::1, m6::1, m7::1, m8::1, m9::1, m10::1, m11::1 >>) do
    <<m0 :: 1, m1 :: 1, m2 :: 1, m3 :: 1, c0 :: 1, m4 :: 1, m5 :: 1, m6 :: 1, c1 :: 1, m7 :: 1, m8 :: 1, m9 :: 1, m10 :: 1, m11 :: 1>>
  end
end
