use Mix.Config

config :mnesia, dir: 'priv/db/#{Mix.env()}/#{node()}'

config :microformats2, atomize_keys: false

config :logger, :console, metadata: [:request_id]

config :floki, :html_parser, Floki.HTMLParser.Html5ever

config :event_bus, topics: [:urls_updated], id_generator: EventBus.Util.Base62
