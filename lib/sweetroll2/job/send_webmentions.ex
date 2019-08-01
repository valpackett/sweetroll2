defmodule Sweetroll2.Job.SendWebmentions do
  alias Sweetroll2.{Post, Markup, Convert}
  require Logger
  use Que.Worker, concurrency: 4

  defp parse_http_links(nil), do: []

  defp parse_http_links(l) when is_list(l), do: parse_http_links(Enum.join(l, ","))

  defp parse_http_links(s) when is_binary(s) do
    case ExHttpLink.parse(s) do
      {:ok, links} ->
        links

      {:error, err} ->
        Logger.warn("could not parse Link header #{inspect(s)}: #{inspect(err)}")
        []
    end
  end

  defp find_http_link(links) when is_list(links) do
    {link, _} =
      Enum.find(links, {nil, nil}, fn {_, rels} ->
        Tuple.to_list(rels)
        |> Stream.chunk_every(2)
        |> Enum.any?(fn [_, v] ->
          String.contains?(" #{v} ", " webmention ")
        end)
      end)

    link
  end

  defp find_html_link(tree) do
    el = Floki.find(tree, "a[href][rel~=webmention], link[href][rel~=webmention]")
    el && List.first(Floki.attribute(el, "href"))
  end

  def discover(base, %HTTPotion.Response{body: body, headers: headers}) when is_binary(base) do
    # TODO: HTML base tag??
    link = find_http_link(parse_http_links(headers[:link])) || find_html_link(Floki.parse(body))

    cond do
      not is_binary(link) ->
        nil

      link == "" ->
        base

      String.starts_with?(link, "http") ->
        link

      String.starts_with?(link, "/") ->
        URI.merge(base, link) |> URI.to_string()

      true ->
        Logger.warn("rel discovery: weird case #{inspect(link)}")
        nil
    end
  end

  def perform(source: source, target: target) do
    endpoint = discover(target, HTTPotion.get!(target))

    res =
      HTTPotion.post!(endpoint,
        headers: ["Content-Type": "application/x-www-form-urlencoded"],
        body: Plug.Conn.Query.encode(%{source: source, target: target}),
        follow_redirects: true
      )

    if HTTPotion.Response.success?(res) do
      Logger.info("sent Webmention: #{inspect(res)}")
    else
      Logger.warn("failed to send Webmention: #{inspect(res)}")
    end
  end

  def perform(url: url, our_home_url: our_home_url) do
    full_url = our_home_url <> url
    post = %Post.DbAsMap{}[url]

    if post do
      for target <- Post.contexts_for(post.props) do
        Que.add(__MODULE__, source: full_url, target: target)
      end

      for link <-
            Floki.find(
              Markup.content_to_tree(Convert.as_one(post.props["content"])),
              "a[href^=http]:not([rel~=nofollow])"
            ) do
        Que.add(__MODULE__, source: full_url, target: List.first(Floki.attribute(link, "href")))
      end
    else
      Logger.info("no post for url #{inspect(url)}")
    end
  end
end