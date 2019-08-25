defmodule Sweetroll2.Post.Generative.Feed do
  @moduledoc """
  Post type processor for `x-dynamic-feed`.
  """

  alias Sweetroll2.{Convert, Post, Post.Generative}

  @behaviour Generative

  def page_url(url, 0), do: url
  def page_url(url, page), do: String.replace_leading("#{url}/page#{page}", "//", "/")

  @impl true
  def apply_args(
        %Post{type: "x-dynamic-feed", url: url, props: props} = post,
        %{page: page},
        posts,
        local_urls
      ) do
    all_children =
      filter_feed_entries(post, posts, local_urls)
      |> sort_feed_entries(posts)

    children = Enum.slice(all_children, page * 10, 10)

    props =
      props
      |> Map.put("x-feed-base-url", url)
      |> Map.put("x-cur-page", page)
      |> Map.put("x-page-count", feed_page_count(all_children))

    %{post | url: page_url(url, page), type: "feed", children: children, props: props}
  end

  @impl true
  def child_urls(%Post{type: "x-dynamic-feed", url: url} = post, posts, local_urls) do
    cnt =
      filter_feed_entries(post, posts, local_urls)
      |> feed_page_count()

    if cnt < 2, do: %{}, else: Map.new(1..(cnt - 1), &{page_url(url, &1), %{page: &1}})
  end

  def filter_feed_entries(%Post{type: type} = feed, posts, local_urls)
      when type == "x-dynamic-feed" or type == "x-dynamic-tag-feed" do
    Stream.filter(
      local_urls,
      &(not is_nil(posts[&1]) and !(posts[&1].deleted || false) and String.starts_with?(&1, "/") and
          in_feed?(posts[&1], feed))
    )
  end

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

  def feed_page_count(entries) do
    # TODO get per_page from feed settings
    ceil(Enum.count(entries) / Application.get_env(:sweetroll2, :entries_per_page, 10))
  end

  @impl true
  @doc """
      iex> Sweetroll2.Post.Generative.Feed.parse_url_segment(nil, "/page123")
      {"", %{page: 123}}

      iex> Sweetroll2.Post.Generative.Feed.parse_url_segment(nil, "/page1/what")
      {"/what", %{page: 1}}
  """
  def parse_url_segment(_, ""), do: {"", %{page: 0}}

  def parse_url_segment(_, "/page" <> n) do
    case Integer.parse(n) do
      {n, rest} -> {rest, %{page: n}}
      :error -> :error
    end
  end

  def parse_url_segment(_, _), do: :error
end
