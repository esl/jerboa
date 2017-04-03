use Mix.Config

config :logger,
  handle_sasl_reports: true,
  level: :info

config :logger, :console,
  metadata: [:jerboa_client, :jerboa_server]

import_config "#{Mix.env}.exs"
