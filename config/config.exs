use Mix.Config

config :sweetroll2, ecto_repos: [Sweetroll2.Repo]

config :microformats2, atomize_keys: false

config :logger, :console, metadata: [:request_id]

config :floki, :html_parser, Floki.HTMLParser.Html5ever

config :event_bus, topics: [:doc_changed]
