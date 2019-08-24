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

  def matches_filter?(%Post{} = post, filter) do
    Enum.all?(filter, fn {k, v} ->
      vals = as_many(post.props[k])
      Enum.all?(as_many(v), &Enum.member?(vals, &1))
    end)
  end

  def matches_filters?(%Post{} = post, filters) do
    Enum.any?(filters, &matches_filter?(post, &1))
  end

  def in_feed?(%Post{} = post, %Post{} = feed) do
    matches_filters?(post, as_many(feed.props["filter"])) and
      not matches_filters?(post, as_many(feed.props["unfilter"]))
  end

  def filter_feed_entries(%Post{type: type} = feed, posts, local_urls)
      when type == "x-dynamic-feed" or type == "x-dynamic-tag-feed" do
    Stream.filter(
      local_urls,
      &(!(posts[&1].deleted || false) and String.starts_with?(&1, "/") and
          in_feed?(posts[&1], feed))
    )
  end

  def filter_feed_entries(%Post{type: "x-inbox-feed"} = feed, posts, local_urls) do
    Stream.filter(
      local_urls,
      &(!(posts[&1].deleted || false) and String.starts_with?(&1, "/"))
    )
    |> Stream.flat_map(&as_many(posts[&1].props["comment"]))
    |> Stream.filter(&(posts[&1] && !(posts[&1].deleted || false) && in_feed?(posts[&1], feed)))
  end

  def sort_feed_entries(urls, posts) do
    now = DateTime.utc_now()

    Enum.sort_by(urls, &(-DateTime.to_unix(posts[&1].published || now)))
  end

  def feed_page_count(entries) do
    # TODO get per_page from feed settings
    ceil(Enum.count(entries) / Application.get_env(:sweetroll2, :entries_per_page, 10))
  end
end
