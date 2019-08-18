defmodule Sweetroll2.Job.NotifyWebsub do
  @default_hub if Mix.env() == :dev,
                 do: "https://httpbin.org/post",
                 else: "https://pubsubhubbub.superfeedr.com/"

  require Logger
  use Que.Worker, concurrency: 4
  alias Sweetroll2.HttpClient

  def hub(), do: System.get_env("SR2_WEBSUB_HUB") || @default_hub

  def perform(url: url) do
    Timber.add_context(que: %{job_id: Logger.metadata()[:job_id]})

    resp = HttpClient.post!(hub(), %{"hub.mode": "publish", "hub.url": url})

    if resp.status >= 200 and resp.status < 300 do
      Logger.info("", event: %{websub_success: resp})
    else
      Logger.info("", event: %{websub_failure: resp})
    end
  end
end
