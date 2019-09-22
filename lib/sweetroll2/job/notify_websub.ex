defmodule Sweetroll2.Job.NotifyWebsub do
  @default_hub if Mix.env() == :dev,
                 do: "https://httpbin.org/post",
                 else: "https://pubsubhubbub.superfeedr.com/"
  @default_granary "https://granary.io/url"

  require Logger
  use Que.Worker, concurrency: 4
  alias Sweetroll2.HttpClient

  def hub, do: System.get_env("SR2_WEBSUB_HUB") || @default_hub
  def granary, do: System.get_env("SR2_GRANARY") || @default_granary

  def granary_url(url, output),
    do:
      granary() <>
        "?" <>
        URI.encode_query(%{"url" => url, "input" => "html", "output" => output, "hub" => hub()})

  def granary_urls(home: home, url: url),
    do: [
      {"alternate home", "application/atom+xml", granary_url(home <> "/", "atom")},
      {"alternate", "application/atom+xml", granary_url(home <> url, "atom")},
      {"alternate", "application/activity+json", granary_url(home <> url, "as2")}
    ]

  def perform(home: home, url: url) do
    perform(url: home <> url)

    for {_, _, gurl} <- granary_urls(home: home, url: url) do
      Que.add(__MODULE__, url: gurl)
    end
  end

  def perform(url: url) do
    Timber.add_context(que: %{job_id: Logger.metadata()[:job_id]})

    resp = HttpClient.post!(hub(), %{"hub.mode": "publish", "hub.url": url})

    if resp.status >= 200 and resp.status < 300 do
      Logger.info("", event: %{websub_success: Map.from_struct(resp)})
    else
      Logger.info("", event: %{websub_failure: Map.from_struct(resp)})
    end
  end
end
