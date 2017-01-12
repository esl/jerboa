defmodule Jerboa.Format.Body.Attribute.XORMappedAddress do
  @moduledoc """

  Encode and decode the XORMappedAddress attribute.

  """

  alias Jerboa.Format.Body.Attribute
  @ip_4 <<0x01 :: 8>>
  @ip_6 <<0x02 :: 8>>

  defmodule IPAddress do
    @moduledoc """

    This does infact have protocol family, IP address, and port number
    fields.

    """

    defstruct [:family, :address, :port]
  end

  def decode(<<_::8, @ip_4, p::16, a::binary>>) do
    %Attribute{name: __MODULE__, value: %__MODULE__.IPAddress{family: 4, address: ip_4(a), port: port(p)}}
  end
  def decode(<<_::8, @ip_6, p::16, a::binary>>) do
    %Attribute{name: __MODULE__, value: %__MODULE__.IPAddress{family: 6, address: ip_6(a), port: p}}
  end

  defp port(x) do
    use Bitwise
    x ^^^ 0x2112
  end

  defp ip_4(x) when 32 === bit_size(x) do
    <<a, b, c, d>> = :crypto.exor x, <<0x2112A442 :: 32>>
    {a, b, c, d}
  end

  defp ip_6(<<a,b,c,d, e,f,g,h>>), do: {a, b, c, d, e, f, g, h}
end
