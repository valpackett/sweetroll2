defmodule Sweetroll2.Notify do
  alias Sweetroll2.Repo
  alias EventBus.Model.Event
  require Logger
  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, :ok, opts)

  @impl GenServer
  def init(:ok) do
    {:ok, pid} = Postgrex.Notifications.start_link(Repo.config())
    {:ok, ref} = Postgrex.Notifications.listen(pid, "doc_changed")
    {:ok, {pid, ref}}
  end

  @impl GenServer
  def handle_info({:notification, _pid, _ref, "doc_changed", payload}, state) do
    Logger.info("PG notification doc_changed payload=#{payload}")

    EventBus.notify(%Event{
      id: DateTime.utc_now() |> DateTime.to_iso8601(),
      topic: :doc_changed,
      data: payload
    })

    {:noreply, state}
  end
end
