defmodule Jerboa.Test.Helper do
  @moduledoc false

  defmodule Server do
    @moduledoc false

    def a do
      configuration(:address)
    end

    def p do
      configuration(:port)
    end

    defp configuration(key) do
      get_in(Application.fetch_env!(:jerboa, :test), [:server, key])
    end
  end
end
