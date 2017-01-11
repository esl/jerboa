defmodule Jerboa.Format.Body.Attribute.MappedAddress do
  @moduledoc """

  Encode and decode the MappedAddress attribute.

  """

  alias Jerboa.Format.Body.Attribute
  @ip_4 <<0x01 :: 8>>
  @ip_6 <<0x02 :: 8>>

  defmodule IPAddress do
    defstruct [:family, :address, :port]
  end

  def decode(<<_::8, @ip_4, p::16, a::binary>>),
    do: %Attribute{name: __MODULE__, value: %__MODULE__.IPAddress{family: 4, address: ip_4(a), port: p}}
  def decode(<<_::8, @ip_6, p::16, a::binary>>),
    do: %Attribute{name: __MODULE__, value: %__MODULE__.IPAddress{family: 6, address: ip_6(a), port: p}}

  defp ip_4(<<a, b, c, d>>), do: {a, b, c, d}

  defp ip_6(<<a,b,c,d, e,f,g,h>>), do: {a, b, c, d, e, f, g, h}
end
