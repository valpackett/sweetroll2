defmodule Sweetroll2.Post.DynamicUrls do
  @moduledoc """
  """

  alias Sweetroll2.Post

  def page_url(url, 0), do: url
  def page_url(url, page), do: String.replace_leading("#{url}/page#{page}", "//", "/")

  def dynamic_urls_for(doc = %Post{type: "x-dynamic-feed"}, preload, allu) do
    cnt = Post.Feed.feed_page_count(Post.Feed.filter_feed_entries(doc, preload, allu))
    Map.new(1..cnt, &{page_url(doc.url, &1), {doc.url, %{page: &1}}})
  end

  # TODO def dynamic_urls_for(doc = %__MODULE__{type: "x-dynamic-tag-feed"}, preload, allu) do end

  def dynamic_urls_for(_, _, _), do: %{}

  def dynamic_urls(preload, allu) do
    Stream.map(allu, &dynamic_urls_for(preload[&1], preload, allu))
    |> Enum.reduce(&Map.merge/2)
  end

end
