defmodule Sweetroll2.MixProject do
  use Mix.Project

  def project do
    [
      app: :sweetroll2,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Sweetroll2.Application, []}
    ]
  end

  defp deps do
    [
      {:ex_early_ret, "~> 0.1"},
      {:timex, "~> 3.5"},
      {:date_time_parser,
       git: "https://github.com/myfreeweb/date_time_parser", branch: "long-microsec"},
      {:jason, "~> 1.1"},
      {:earmark, "~> 1.3"},
      {:phoenix_html, "~> 2.13"},
      {:taggart, "~> 0.1.5"},
      {:floki, git: "https://github.com/philss/floki", override: true},
      {:html_sanitize_ex, "~> 1.3"},
      {:rustler, "~> 0.20.0", override: true},
      {:html5ever, "~> 0.7.0"},
      {:rustled_syntect, "~> 0.1"},
      {:microformats2,
       git: "https://github.com/myfreeweb/microformats2-elixir", branch: "no-underscores"},
      {:plug_micropub, git: "https://github.com/bismark/plug_micropub"},
      {:ex_http_link, "~> 0.1.2"},
      {:argon2_elixir, "~> 2.0"},
      {:nanoid, "~> 2.0.1"},
      {:slugger, "~> 0.3.0"},
      {:file_system, git: "https://github.com/falood/file_system"},
      {:debounce, "~> 0.1.0"},
      {:con_cache, "~> 0.13"},
      {:quantum, "~> 2.3"},
      {:memento, "~> 0.3.1"},
      {:liquid, "~> 0.9"},
      {:nimble_parsec, "~> 0.5", override: true},
      {:que, git: "https://github.com/myfreeweb/que", branch: "logger-meta"},
      {:ssl_verify_fun, "~> 1.1", override: true},
      {:hackney, "~> 1.15"},
      {:tesla, git: "https://github.com/myfreeweb/tesla", branch: "rel-redir"},
      {:hammer, "~> 6.0"},
      {:timber, "~> 3.1"},
      {:timber_plug, "~> 1.0"},
      {:timber_exceptions, "~> 2.0"},
      {:exceptional, "~> 2.1"},
      {:plug_cowboy, "~> 2.0"},
      {:remote_ip, "~> 0.1.0"},
      {:sse, "~> 0.4"},
      {:event_bus, ">= 1.6.0"},
      {:credo, "~> 1.1", only: [:dev], runtime: false}
    ]
  end
end
