defmodule Sweetroll2.Post.DynamicUrls do
  @moduledoc """
  Rules for special post types that create more than one URL. Currently:

  - dynamic feeds are paginated, so they create `feed_url/pageN` for their pages
  - the tag feeds are paginated, so you get `tag_url/TAG/pageN`
    NOTE: the `tag_url/TAG` rule is also replicated in Post.Tags.feeds_get_with_tags
  """

  alias Sweetroll2.Post

  def page_url(url, 0), do: url
  def page_url(url, page), do: String.replace_leading("#{url}/page#{page}", "//", "/")

  def dynamic_urls_for(post = %Post{type: post_type}, posts, local_urls)
      when post_type == "x-dynamic-feed" or post_type == "x-inbox-feed" do
    cnt = Post.Feed.feed_page_count(Post.Feed.filter_feed_entries(post, posts, local_urls))
    Map.new(1..(cnt - 1), &{page_url(post.url, &1), {post.url, %{page: &1}}})
  end

  def dynamic_urls_for(post = %Post{type: "x-dynamic-tag-feed"}, posts, local_urls) do
    Stream.map(Post.Tags.all_tags(), fn tag ->
      cnt =
        Post.Tags.subst_tag(post, tag)
        |> Post.Feed.filter_feed_entries(posts, local_urls)
        |> Post.Feed.feed_page_count()

      # NOTE: starting from zero as just the tag itself is also dynamic
      Map.new(
        0..(cnt - 1),
        &{page_url("#{post.url}/#{tag}", &1), {post.url, %{tag: tag, page: &1}}}
      )
    end)
    |> Enum.reduce(&Map.merge/2)
  end

  def dynamic_urls_for(_, _, _), do: %{}

  def dynamic_urls_with(posts, local_urls) do
    Stream.map(local_urls, &dynamic_urls_for(posts[&1], posts, local_urls))
    |> Enum.reduce(&Map.merge/2)
  end

  def dynamic_urls_raw, do: dynamic_urls_with(%Post.DbAsMap{}, Post.urls_local())

  def dynamic_urls, do: ConCache.get_or_store(:misc, :dynamic_urls, &dynamic_urls_raw/0)

  def clear_cached_urls, do: ConCache.delete(:misc, :dynamic_urls)
end
