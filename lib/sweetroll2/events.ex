defmodule Sweetroll2.Events do
  @moduledoc """
  A GenServer for automatic event handling.
  """

  @debounce_ms 2000

  require Logger
  alias Sweetroll2.{Post, Job}
  use EventBus.EventSource
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok) do
    EventBus.subscribe({__MODULE__, ["url_updated"]})
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:url_updated, _id} = event_shadow, state) do
    %{data: %SSE.Chunk{data: url}} = EventBus.fetch_event(event_shadow)

    Job.Generate.remove_generated(url)
    Post.Page.clear_cached_template(url: url)

    Que.add(Job.Generate,
      urls: [url],
      next_jobs: [
        {Job.NotifyWebsub, home: Sweetroll2.canonical_home_url(), url: url},
        {Job.SendWebmentions, url: url, our_home_url: Sweetroll2.canonical_home_url()}
      ]
    )

    EventBus.mark_as_completed({__MODULE__, event_shadow})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:notify_url_for_real, url}, state) do
    Logger.debug("finished debounce for url '#{url}', notifying event bus",
      event: %{debounce_finished: %{url: url}}
    )

    EventSource.notify(%{topic: :url_updated}, do: %SSE.Chunk{data: url})
    {:noreply, Map.delete(state, url)}
  end

  @impl true
  def handle_cast({:notify_url_req, url}, state) do
    if Map.has_key?(state, url) do
      Debounce.apply(state[url])

      Logger.debug("reset debounce for url '#{url}': #{inspect(state[url])}",
        event: %{debounce_reset: %{url: url}}
      )

      {:noreply, state}
    else
      {:ok, pid} =
        Debounce.start_link(
          {GenServer, :cast, [__MODULE__, {:notify_url_for_real, url}]},
          @debounce_ms
        )

      Debounce.apply(pid)

      Logger.debug("started debounce for url '#{url}': #{inspect(pid)}",
        event: %{debounce_started: %{url: url}}
      )

      {:noreply, Map.put(state, url, pid)}
    end
  end

  @doc "callback for EventBus"
  def process(event_shadow) do
    GenServer.cast(__MODULE__, event_shadow)
    :ok
  end

  def notify_urls_updated([]) do
  end

  def notify_urls_updated(urls) when is_list(urls) do
    for url <- urls do
      GenServer.cast(__MODULE__, {:notify_url_req, url})
      aff = affected_urls(url)

      Logger.info("updating affected urls",
        event: %{affected_discovered: %{url: url, affected: aff}}
      )

      notify_urls_updated(aff)
    end
  end

  defp affected_urls(url) do
    posts = %Post.DbAsMap{}

    if is_nil(posts[url]) do
      []
    else
      local_urls = Post.urls_local()

      # TODO: use a previous copy of the post to find feeds that formerly contained it!!

      aff_feeds =
        Post.filter_type(local_urls, posts, ["x-dynamic-feed", "x-dynamic-tag-feed"])
        |> Post.Generative.Tag.feeds_get_with_tags(posts: posts, local_urls: local_urls)
        |> Enum.filter(&Post.Generative.Feed.in_feed?(posts[url], &1))

      aff_page_urls =
        Post.filter_type(local_urls, posts, "x-custom-page")
        |> Enum.filter(fn page_url ->
          Enum.any?(Post.Page.used_feeds(posts[page_url]), &(&1 == url))
        end)

      Enum.flat_map(
        aff_feeds,
        &[&1.url | Post.Generative.child_urls_rec(&1, posts, local_urls)]
      ) ++ aff_page_urls ++ Post.Generative.child_urls_rec(posts[url], posts, local_urls)
    end
  end
end
