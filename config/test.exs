use Mix.Config

config :jerboa, :test,
  server: [%{name: "Google",
             address: {74, 125, 143, 127},
             port: 19_302}
          ]
