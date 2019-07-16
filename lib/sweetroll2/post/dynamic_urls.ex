defmodule Sweetroll2.Post.DynamicUrls do
  @moduledoc """
  Rules for special post types that create more than one URL. Currently:

  - dynamic feeds are paginated, so they create `feed_url/pageN` for their pages
  """

  alias Sweetroll2.Post

  def page_url(url, 0), do: url
  def page_url(url, page), do: String.replace_leading("#{url}/page#{page}", "//", "/")

  def dynamic_urls_for(post = %Post{type: "x-dynamic-feed"}, posts, local_urls) do
    cnt = Post.Feed.feed_page_count(Post.Feed.filter_feed_entries(post, posts, local_urls))
    Map.new(1..cnt, &{page_url(post.url, &1), {post.url, %{page: &1}}})
  end

  # TODO def dynamic_urls_for(post = %__MODULE__{type: "x-dynamic-tag-feed"}, posts, local_urls) do end

  def dynamic_urls_for(_, _, _), do: %{}

  def dynamic_urls(posts, local_urls) do
    Stream.map(local_urls, &dynamic_urls_for(posts[&1], posts, local_urls))
    |> Enum.reduce(&Map.merge/2)
  end

  defmodule Cache do
    use Agent
    alias Sweetroll2.Post

    def start_link(_) do
      Agent.start_link(fn -> nil end, name: __MODULE__)
    end

    def dynamic_urls() do
      if result = Agent.get(__MODULE__, & &1) do
        result
      else
        result = Post.DynamicUrls.dynamic_urls(%Post.DbAsMap{}, Post.urls_local())
        Agent.update(__MODULE__, fn _ -> result end)
        result
      end
    end

    def clear() do
      Agent.update(__MODULE__, fn _ -> nil end)
    end
  end
end
