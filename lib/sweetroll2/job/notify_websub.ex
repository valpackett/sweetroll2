defmodule Sweetroll2.Job.NotifyWebsub do
  @default_hub if Mix.env() == :dev,
                 do: "https://httpbin.org/post",
                 else: "https://pubsubhubbub.superfeedr.com/"

  require Logger
  use Que.Worker, concurrency: 4

  def hub(), do: System.get_env("SR2_WEBSUB_HUB") || @default_hub

  def perform(url: url) do
    res =
      HTTPotion.post!(hub(),
        headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: Plug.Conn.Query.encode(%{"hub.mode": "publish", "hub.url": url})
      )

    if HTTPotion.Response.success?(res) do
      Logger.info("notified WebSub hub: #{inspect(res)}")
    else
      Logger.warn("failed to notify WebSub hub: #{inspect(res)}")
    end
  end
end
