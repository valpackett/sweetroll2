defmodule Sweetroll2.Post.Generative.Inbox do
  @moduledoc """
  Post type processor for `x-inbox-feed`.
  """

  alias Sweetroll2.{
    Convert,
    Post,
    Post.Generative,
    Post.Generative.Feed,
    Post.Generative.Pagination
  }

  @behaviour Generative

  defp to_paginated_feed(post, posts, local_urls) do
    children =
      filter_feed_entries(post, posts, local_urls)
      |> Feed.sort_feed_entries(posts)

    %{post | type: "x-paginated-feed", children: children}
  end

  @impl true
  def apply_args(%Post{type: "x-inbox-feed"} = post, args, posts, local_urls) do
    to_paginated_feed(post, posts, local_urls)
    |> Pagination.apply_args(args, posts, local_urls)
  end

  @impl true
  def child_urls(%Post{type: "x-inbox-feed"} = post, posts, local_urls) do
    to_paginated_feed(post, posts, local_urls)
    |> Pagination.child_urls(posts, local_urls)
  end

  def filter_feed_entries(%Post{type: "x-inbox-feed"} = feed, posts, local_urls) do
    Stream.filter(
      local_urls,
      &(not is_nil(posts[&1]) and !(posts[&1].deleted || false) and String.starts_with?(&1, "/"))
    )
    |> Stream.flat_map(&Convert.as_many(posts[&1].props["comment"]))
    |> Stream.uniq()
    |> Stream.filter(
      &(posts[&1] && !(posts[&1].deleted || false) && Feed.in_feed?(posts[&1], feed))
    )
  end

  @impl true
  defdelegate parse_url_segment(post, seg), to: Pagination
end
