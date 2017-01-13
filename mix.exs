defmodule Jerboa.Mixfile do
  use Mix.Project

  def project do
    [app: :jerboa,
     version: "0.1.0",
     description: "STUN/TURN encoder, decoder and client library",
     elixir: "~> 1.4-rc",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     docs: docs(),
     dialyzer: dialyzer(),
     test_coverage: test_coverage(),
     preferred_cli_env: preferred_cli_env()]
  end

  def application do
    [extra_applications: [:logger],
     mod: {Jerboa.Client.Application, []}]
  end

  defp deps do
    [{:ex_doc, "~> 0.14", runtime: false, only: :dev},
     {:credo, "~> 0.5", runtime: false, only: [:dev, :test]},
     {:dialyxir, "~> 0.4", runtime: false, only: :dev},
     {:excoveralls, "~> 0.5", runtime: false, only: :test},
     {:inch_ex, "~> 0.5", runtime: false, only: :dev},
     {:quixir, "~> 0.9", runtime: false, only: :test}]
  end

  defp docs do
    [main: "Jerboa"]
  end

  defp dialyzer do
    [plt_core_path: ".dialyzer/",
     flags: ["-Wunmatched_returns", "-Werror_handling",
             "-Wrace_conditions", "-Wunderspecs"]]
  end

  defp test_coverage do
    [tool: ExCoveralls]
  end

  defp preferred_cli_env do
    ["coveralls": :test, "coveralls.detail": :test,
     "coveralls.travis": :test, "coveralls.html": :test]
  end
end
