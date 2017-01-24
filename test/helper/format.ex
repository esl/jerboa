defmodule Jerboa.Test.Helper.Format do
  @moduledoc false

  def binding_request do
    %Jerboa.Params{
      class: :request,
      method: :binding,
      identifier: :crypto.strong_rand_bytes(div 96, 8),
      body: <<>>
    }
  end
end
