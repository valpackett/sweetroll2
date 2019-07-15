defmodule Sweetroll2.Events do
  @moduledoc """
  A GenServer for automatic event handling.
  """

  require Logger
  alias Sweetroll2.{Post, Job}
  use EventBus.EventSource
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok) do
    EventBus.subscribe({__MODULE__, ["urls_updated"]})
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:urls_updated, _id} = event_shadow, state) do
    event = EventBus.fetch_event(event_shadow)

    for url <- event.data do
      affected = affected_urls(url)
      Logger.info("potentially affected by '#{url}': #{inspect(affected)}")
      notify_urls_updated(affected)
    end

    Que.add(Job.Generate, urls: event.data)

    EventBus.mark_as_completed({__MODULE__, event_shadow})
    {:noreply, state}
  end

  @doc "callback for EventBus"
  def process(event_shadow) do
    GenServer.cast(__MODULE__, event_shadow)
    :ok
  end

  def notify_urls_updated([]) do
  end

  def notify_urls_updated(urls) when is_list(urls) do
    EventSource.notify %{topic: :urls_updated} do
      urls
    end
  end

  defp affected_urls(url) do
    posts = %Post.DbAsMap{}

    if is_nil(posts[url]) do
      []
    else
      local_urls = Post.urls_local()

      Post.Feed.filter_feeds(local_urls, posts)
      |> Stream.filter(&Post.Feed.in_feed?(posts[url], posts[&1]))
      |> Enum.flat_map(
        &[&1 | Map.keys(Post.DynamicUrls.dynamic_urls_for(posts[&1], posts, local_urls))]
      )
    end
  end
end
