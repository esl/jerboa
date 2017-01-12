defmodule Jerboa.Format.Head.Type do
  @moduledoc """

  Encode and decode the class and method to and from the type.

  """

  defmodule Class do
    @moduledoc """

    Encode and decode the class. These are fixed into the two bits for
    coding them so addtions will never be made here.

    """

    def encode(:request),    do: <<0 :: 2>>
    def encode(:indication), do: <<1 :: 2>>
    def encode(:success),    do: <<2 :: 2>>
    def encode(:failure),    do: <<3 :: 2>>

    def decode(<<0 :: 2>>), do: :request
    def decode(<<1 :: 2>>), do: :indication
    def decode(<<2 :: 2>>), do: :success
    def decode(<<3 :: 2>>), do: :failure
  end

  defmodule Method do
    @moduledoc """

    Encode and decode the method. These are described in various RFCs
    so addtions will be made here.

    """

    def encode(:binding), do: <<0x0001 :: 12>>

    def decode(<<0x0001 :: 12>>), do: :binding
  end

  def encode(%Jerboa.Format{class: x, method: y}) do
    encode Class.encode(x), Method.encode(y)
  end

  def decode(<<m0_4::5-bits, c0::1, m5_7::3-bits, c1::1, m7_10::4-bits>>) do
    [class: Class.decode(<<c0::1, c1::1>>),
     method: Method.decode(<<m0_4::5-bits, m5_7::3-bits, m7_10::4-bits>>)]
  end

  defp encode(<< c0::1, c1::1 >>, << m0::1, m1::1, m2::1, m3::1, m4::1, m5::1, m6::1, m7::1, m8::1, m9::1, m10::1, m11::1 >>) do
    <<m0 :: 1, m1 :: 1, m2 :: 1, m3 :: 1, c0 :: 1, m4 :: 1, m5 :: 1, m6 :: 1, c1 :: 1, m7 :: 1, m8 :: 1, m9 :: 1, m10 :: 1, m11 :: 1>>
  end
end
