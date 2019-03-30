use Mix.Config

config :sweetroll2, ecto_repos: [Sweetroll2.Repo]

config :logger, :console, metadata: [:request_id]
