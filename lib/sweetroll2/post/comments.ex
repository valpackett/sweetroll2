defmodule Sweetroll2.Post.Comments do
  @moduledoc """
  Data helpers for presenting post responses/reactions.
  """

  require Logger
  import Sweetroll2.Convert
  alias Sweetroll2.Post

  @doc """
  Splits "comments" (saved webmentions) by post type.

  Requires entries to be maps (does not load urls from the database).
  i.e. inline_comments should be done first.

  Lists are reversed.
  """
  def separate_comments(%Post{url: url, props: %{"comment" => comments}})
      when is_list(comments) do
    Enum.reduce(comments, %{}, fn x, acc ->
      cond do
        # TODO reacji
        compare_property(x, "in-reply-to", url) -> Map.update(acc, :replies, [x], &[x | &1])
        compare_property(x, "like-of", url) -> Map.update(acc, :likes, [x], &[x | &1])
        compare_property(x, "repost-of", url) -> Map.update(acc, :reposts, [x], &[x | &1])
        compare_property(x, "bookmark-of", url) -> Map.update(acc, :bookmarks, [x], &[x | &1])
        compare_property(x, "quotation-of", url) -> Map.update(acc, :quotations, [x], &[x | &1])
        true -> acc
      end
    end)
  end

  def separate_comments(%Post{}), do: %{}

  @doc """
  Inlines posts mentioned by URL in the `comment` property.

  The inlined ones are Post structs, but other things in the array remain as-is.
  """
  def inline_comments(post = %Post{url: url, props: props}, posts) do
    Logger.debug("inline comments: working on #{url}")

    comments =
      props["comment"]
      |> as_many()
      |> Enum.map(fn
        u when is_bitstring(u) ->
          Logger.debug("inline comments: inlining #{u}")
          posts[u]

        x ->
          x
      end)

    Map.put(post, :props, Map.put(props, "comment", comments))
  end

  def inline_comments(post_url, posts) when is_bitstring(post_url) do
    Logger.debug("inline comments: loading #{post_url}")
    res = posts[post_url]
    if res != post_url, do: inline_comments(res, posts), else: res
  end

  def inline_comments(x, _), do: x

  defp lookup_property(%Post{props: props}, prop), do: props[prop]

  defp lookup_property(x, prop) when is_map(x) do
    x[prop] || x["properties"][prop] || x[:properties][prop] || x["props"][prop] ||
      x[:props][prop]
  end

  defp lookup_property(_, _), do: false

  defp get_url(s) when is_bitstring(s), do: s

  defp get_url(m) when is_map(m), do: lookup_property(m, "url")

  defp compare_property(x, prop, url) when is_bitstring(prop) and is_bitstring(url) do
    lookup_property(x, prop)
    |> as_many()
    |> Stream.map(&get_url/1)
    |> Enum.any?(fn val ->
      url && val &&
        (val == url || URI.parse(val).path == URI.parse(url).path)
    end)

    # Assumes that path match is enough to avoid needing to know our host.
    # If a post is already in the comments list, it has been verified to link here.
    # Faking e.g. a like by liking the same path on a different domain and just mentioning this one is..
    # Not a significant concern really.
  end
end
