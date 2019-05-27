defmodule Sweetroll2.Post.Feed do
  @moduledoc """
  Data helpers for displaying dynamic feeds.

  A feed is a special post with type `"x-dynamic-feed"` that contains configuration,
  such as filters that determine which posts end up in the feed.
  When rendering a dynamic feed, Sweetroll2 will automatically insert matching posts.

  Feeds are paginated via dynamic URLs.
  """

  import Sweetroll2.Convert
  alias Sweetroll2.Post

  def matches_filter?(doc = %Post{}, filter) do
    Enum.all?(filter, fn {k, v} ->
      docv = as_many(doc.props[k])
      Enum.all?(as_many(v), &Enum.member?(docv, &1))
    end)
  end

  def matches_filters?(doc = %Post{}, filters) do
    Enum.any?(filters, &matches_filter?(doc, &1))
  end

  def in_feed?(doc = %Post{}, feed = %Post{}) do
    matches_filters?(doc, as_many(feed.props["filter"])) and
      not matches_filters?(doc, as_many(feed.props["unfilter"]))
  end

  def filter_feeds(urls, preload) do
    Stream.filter(urls, fn url ->
      String.starts_with?(url, "/") && preload[url] && preload[url].type == "x-dynamic-feed"
    end)
  end

  def filter_feed_entries(doc = %Post{type: "x-dynamic-feed"}, preload, allu) do
    Stream.filter(allu, &(String.starts_with?(&1, "/") and in_feed?(preload[&1], doc)))
    |> Enum.sort(
      &(DateTime.compare(
          preload[&1].published || DateTime.utc_now(),
          preload[&2].published || DateTime.utc_now()
        ) == :gt)
    )
  end

  def feed_page_count(entries) do
    # TODO get per_page from feed settings
    ceil(Enum.count(entries) / Application.get_env(:sweetroll2, :entries_per_page, 10))
  end

end
