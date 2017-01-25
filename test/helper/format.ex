defmodule Jerboa.Test.Helper.Format do
  @moduledoc false

  def binding_request do
    %Jerboa.Params{
      class: :request,
      method: :binding,
      identifier: Jerboa.Test.Helper.Header.i(),
      body: <<>>
    }
  end
end
