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
     dialyzer: dialyzer()]
  end

  def application do
    [extra_applications: [:logger],
     mod: {Jerboa.Application, []}]
  end

  defp deps do
    [{:ex_doc, "~> 0.14", runtime: false, only: :dev},
     {:credo, "~> 0.5", runtime: false, only: [:dev, :test]},
     {:dialyxir, "~> 0.4", runtime: false, only: :dev}]
  end

  defp docs do
    [main: "Jerboa"]
  end

  defp dialyzer do
    [plt_core_path: ".dialyzer/",
     flags: ["-Wunmatched_returns", "-Werror_handling",
             "-Wrace_conditions", "-Wunderspecs"]]
  end
end
