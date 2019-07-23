use Mix.Config

config :mnesia, dir: 'priv/db/#{Mix.env()}/#{node()}'

config :ibrowse, max_headers_size: 10240

config :httpotion, :default_headers, "user-agent": "Sweetroll2 (HTTPotion/ibrowse)"

config :microformats2, atomize_keys: false, underscore_keys: false

config :logger, :console, metadata: [:request_id]

config :floki, :html_parser, Floki.HTMLParser.Html5ever

config :event_bus, topics: [:urls_updated], id_generator: EventBus.Util.Base62

config :sweetroll2, Sweetroll2.Application.Scheduler,
  jobs:
    [
      {"@reboot", {Sweetroll2.Job.Compress, :enqueue_assets, []}}
    ] ++
      if(Mix.env() == :prod,
        do: [
          {"@reboot", {Sweetroll2.Job.Generate, :enqueue_all, []}},
          {"@hourly", {Sweetroll2.Job.Generate, :enqueue_all, []}}
        ],
        else: []
      )
