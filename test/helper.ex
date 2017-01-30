defmodule Jerboa.Test.Helper do
  @moduledoc false

  defmodule Server do
    @moduledoc false

    def address do
      configuration(:address)
    end

    def port do
      configuration(:port)
    end

    defp configuration(key) do
      get_in(Application.fetch_env!(:jerboa, :test), [:server, key])
    end
  end
end
