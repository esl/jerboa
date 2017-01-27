defmodule Jerboa.Test.Helper.Format do
  @moduledoc false

  def binding_request do
    %Jerboa.Params{
      class: :request,
      method: :binding,
      identifier: Jerboa.Test.Helper.Header.identifier(),
      body: <<>>
    }
  end

  def bytes_for_body(<<_::16, x::16, _::128, _::size(x)-bytes>>) do
    x
  end
end
