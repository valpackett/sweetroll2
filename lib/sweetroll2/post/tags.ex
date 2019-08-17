defmodule Sweetroll2.Post.Tags do
  alias Sweetroll2.{Post, Convert}
  require Logger

  def all_tags do
    ConCache.get_or_store(:misc, :all_tags, &all_tags_raw/0)
  end

  def all_tags_raw do
    posts = %Post.DbAsMap{}

    Post.urls_local()
    |> Stream.flat_map(&Convert.as_many(posts[&1].props["category"]))
    |> Stream.filter(&(is_binary(&1) and !String.starts_with?(&1, "_")))
    |> Enum.uniq()
  end

  def clear_cached_tags, do: ConCache.delete(:misc, :all_tags)

  def feeds_get_with_tags(feed_urls, posts: posts) do
    Enum.flat_map(feed_urls, fn url ->
      post = posts[url]

      if post.type == "x-dynamic-tag-feed" do
        Enum.map(all_tags, &subst_tag(post, &1))
      else
        [post]
      end
    end)
  end

  @doc """
      iex> Sweetroll2.Post.Tags.subst_tag(%Post{type: "x-dynamic-tag-feed", url: "/tg", props: %{"name" => "_{tag}_", "filter" => [%{"category" => ["{tag}"]}]}}, "memes")
      %Post{type: "x-dynamic-feed", url: "/tg/memes", props: %{"name" => "_memes_", "filter" => [%{"category" => ["memes"]}]}}
  """
  def subst_tag(post = %Post{url: url, props: props}, tag) do
    props =
      props
      |> Map.update("name", tag, &String.replace(Convert.as_one(&1), "{tag}", tag))
      |> Map.update("filter", [], &subst_inner(Convert.as_many(&1), tag))

    %{post | type: "x-dynamic-feed", props: props, url: "#{url}/#{tag}"}
  end

  defp subst_inner(m, tag) when is_map(m),
    do: Enum.map(m, fn {k, v} -> {k, subst_inner(v, tag)} end) |> Enum.into(%{})

  defp subst_inner(l, tag) when is_list(l), do: Enum.map(l, &subst_inner(&1, tag))
  defp subst_inner(s, tag) when is_binary(s), do: String.replace(s, "{tag}", tag)
  defp subst_inner(x, _), do: x
end
