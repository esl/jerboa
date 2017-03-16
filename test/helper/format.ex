defmodule Jerboa.Test.Helper.Format do
  @moduledoc false

  alias Jerboa.Params

  def binding_request do
    Params.new()
    |> Params.put_class(:request)
    |> Params.put_method(:binding)
  end

  def bytes_for_body(<<_::16, x::16, _::128, _::size(x)-bytes>>) do
    x
  end
end
