defmodule Sweetroll2.Post.Generative.Feed do
  @moduledoc """
  Post type processor for `x-dynamic-feed`.
  """

  alias Sweetroll2.{Convert, Post, Post.Generative, Post.Generative.Pagination}

  @behaviour Generative

  defp to_paginated_feed(post, posts, local_urls) do
    children =
      filter_feed_entries(post, posts, local_urls)
      |> sort_feed_entries(posts)

    %{post | type: "x-paginated-feed", children: children}
  end

  @impl true
  def apply_args(%Post{type: "x-dynamic-feed"} = post, args, posts, local_urls) do
    to_paginated_feed(post, posts, local_urls)
    |> Pagination.apply_args(args, posts, local_urls)
  end

  @impl true
  def child_urls(%Post{type: "x-dynamic-feed"} = post, posts, local_urls) do
    to_paginated_feed(post, posts, local_urls)
    |> Pagination.child_urls(posts, local_urls)
  end

  def filter_feed_entries(%Post{type: type} = feed, posts, local_urls)
      when type == "x-dynamic-feed" or type == "x-dynamic-tag-feed" do
    Stream.filter(
      local_urls,
      &(not is_nil(posts[&1]) and !(posts[&1].deleted || false) and String.starts_with?(&1, "/") and
          in_feed?(posts[&1], feed))
    )
  end

  @doc """
      iex> Feed.matches_filter?(%Post{props: %{"category" => "test", "x" => "y"}}, %{"category" => "test"})
      true

      iex> Feed.matches_filter?(%Post{props: %{"category" => ["test", "memes"], "what" => "ever"}}, %{"category" => "test"})
      true

      iex> Feed.matches_filter?(%Post{props: %{"category" => ["test"], "ping" => "pong"}}, %{"category" => ["test"]})
      true

      iex> Feed.matches_filter?(%Post{props: %{"category" => [], "ping" => "pong"}}, %{"category" => ["test"]})
      false

      iex> Feed.matches_filter?(%Post{props: %{"aaa" => "bbb"}}, %{"category" => ["test"]})
      false
  """
  def matches_filter?(%Post{} = post, filter) do
    Enum.all?(filter, fn {k, v} ->
      vals = Convert.as_many(post.props[k])
      Enum.all?(Convert.as_many(v), &Enum.member?(vals, &1))
    end)
  end

  def matches_filters?(%Post{} = post, filters) do
    Enum.any?(filters, &matches_filter?(post, &1))
  end

  def in_feed?(%Post{} = post, %Post{} = feed) do
    matches_filters?(post, Convert.as_many(feed.props["filter"])) and
      not matches_filters?(post, Convert.as_many(feed.props["unfilter"]))
  end

  def sort_feed_entries(urls, posts) do
    now = DateTime.utc_now()

    Enum.sort_by(urls, &(-DateTime.to_unix((posts[&1] && posts[&1].published) || now)))
  end

  @impl true
  defdelegate parse_url_segment(post, seg), to: Pagination
end
