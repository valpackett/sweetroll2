defmodule Sweetroll2.Job.NotifyWebsub do
  @default_hub if Mix.env() == :dev,
                 do: "https://httpbin.org/post",
                 else: "https://pubsubhubbub.superfeedr.com/"

  require Logger
  use Que.Worker, concurrency: 4

  def hub(), do: System.get_env("SR2_WEBSUB_HUB") || @default_hub

  def perform(url: url) do
    Timber.add_context(que: %{job_id: Logger.metadata()[:job_id]})

    res =
      HTTPotion.post!(hub(),
        headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: Plug.Conn.Query.encode(%{"hub.mode": "publish", "hub.url": url})
      )

    if HTTPotion.Response.success?(res) do
      Logger.info("", event: %{websub_success: res})
    else
      Logger.info("", event: %{websub_failure: res})
    end
  end
end
