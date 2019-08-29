defmodule Sweetroll2.Post.Generative.Tag do
  @moduledoc """
  Post type processor for `x-dynamic-tag-feed`.
  """

  alias Sweetroll2.{Convert, Post, Post.Generative}

  @behaviour Generative

  # TODO: something with this
  def feeds_get_with_tags(feed_urls, posts: posts, local_urls: local_urls) do
    Enum.flat_map(feed_urls, fn url ->
      post = posts[url]

      if post.type == "x-dynamic-tag-feed" do
        child_urls(post, posts, local_urls)
        |> Map.values()
        |> Enum.map(&apply_args(post, &1, posts, local_urls))
      else
        [post]
      end
    end)
  end

  @impl true
  def apply_args(
        %Post{type: "x-dynamic-tag-feed", url: url, props: props} = post,
        %{tag: tag},
        _,
        _
      ) do
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

  @impl true
  def child_urls(%Post{type: "x-dynamic-tag-feed", url: url}, posts, local_urls) do
    local_urls
    |> Stream.flat_map(&Convert.as_many(posts[&1].props["category"]))
    |> Stream.filter(&(is_binary(&1) and !String.starts_with?(&1, "_")))
    |> Enum.uniq()
    |> Map.new(&{url <> "/" <> &1, %{tag: &1}})
  end

  @impl true
  @doc """
      iex> Tag.parse_url_segment(nil, "/whatevs")
      {"", %{tag: "whatevs"}}

      iex> Tag.parse_url_segment(nil, "/hello%20world/page69")
      {"/page69", %{tag: "hello%20world"}}
  """

  def parse_url_segment(_, "/" <> arg) do
    case String.split(arg, "/", parts: 2) do
      [tag, rest] -> {"/" <> rest, %{tag: tag}}
      [tag] -> {"", %{tag: tag}}
      _ -> :error
    end
  end

  def parse_url_segment(_, ""), do: {"", %{tag: ""}}

  def parse_url_segment(_, _), do: :error
end
