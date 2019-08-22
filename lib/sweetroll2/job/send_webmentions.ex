defmodule Sweetroll2.Job.SendWebmentions do
  alias Sweetroll2.{Post, Markup, Convert, HttpClient}
  require Logger
  use Que.Worker, concurrency: 4

  defp parse_http_links(nil), do: []
  defp parse_http_links([]), do: []
  defp parse_http_links(""), do: []

  defp parse_http_links(l) when is_list(l), do: parse_http_links(Enum.join(l, ","))

  defp parse_http_links(s) when is_binary(s) do
    case ExHttpLink.parse(s) do
      {:ok, links} ->
        links

      {:error, err} ->
        Logger.warn("could not parse Link header",
          event: %{failed_link_header_parse: %{header: s, error: inspect(err)}}
        )

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

  def discover(base, resp = %Tesla.Env{body: body}) when is_binary(base) do
    # TODO: HTML base tag??
    link =
      find_http_link(parse_http_links(Tesla.get_headers(resp, "link"))) ||
        find_html_link(Floki.parse(body))

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
    Timber.add_context(que: %{job_id: Logger.metadata()[:job_id]})

    Logger.info("sending", event: %{webmention_start: %{source: source, target: target}})

    endpoint = discover(target, HttpClient.get!(target))

    Logger.info("endpoint '#{endpoint}' found",
      event: %{webmention_endpoint_discovered: %{endpoint: endpoint, for: target}}
    )

    resp = HttpClient.post!(endpoint, %{source: source, target: target})

    if resp.status >= 200 and resp.status < 300 do
      Logger.info("sent", event: %{webmention_success: resp})
    else
      Logger.warn("failed to send", event: %{webmention_failure: resp})
    end
  end

  def perform(url: url, our_home_url: our_home_url) do
    Timber.add_context(que: %{job_id: Logger.metadata()[:job_id]})

    full_url = our_home_url <> url
    post = %Post.DbAsMap{}[url]

    if post do
      for target <-
            MapSet.union(
              Post.contexts_for(post.props),
              Markup.contexts_for(Convert.as_one(post.props["content"]))
            ) do
        Que.add(__MODULE__, source: full_url, target: target)
      end

      # TODO: also move these to a different property so that we don't pester
      # no-longer-mentioned sites with our removed mentions too much
      for target <- post.props["x-sr2-ctxs-removed"] || [] do
        Que.add(__MODULE__, source: full_url, target: target)
      end
    else
      Logger.info("no post for url #{inspect(url)}",
        event: %{webmention_no_post: %{url: url, our_home_url: our_home_url}}
      )
    end
  end
end
