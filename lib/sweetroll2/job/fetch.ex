defmodule Sweetroll2.Job.Fetch do
  alias Sweetroll2.{Events, Post, Convert, HttpClient}
  require Logger
  import ExEarlyRet
  use Que.Worker, concurrency: 4

  def href_matches?({_, attrs, _}, url) do
    attrs
    |> Enum.filter(fn {k, _} -> k == "href" end)
    |> Enum.all?(fn {_, v} -> v == url end)
  end

  defearlyret fetch(url, check_mention: check_mention) do
    u = URI.parse(url)

    ret_if u.scheme != "http" && u.scheme != "https", do: {:non_http_scheme, u.scheme}

    # TODO: check IP address ranges too.. or just ban IP addreses
    ret_if u.host == nil || u.host == "localhost", do: {:local_host, u.host}

    resp = HttpClient.get!(url, headers: [{"accept", "text/html"}])

    ret_if resp.status == 410, do: {:gone, resp}

    html = Floki.parse(resp.body)

    ret_if check_mention &&
             not Enum.any?(Floki.find(html, "a"), &href_matches?(&1, check_mention)),
           do: {:no_mention, check_mention}

    mf =
      Microformats2.parse(html, url)
      |> Convert.find_mf_with_url(url)
      |> Convert.simplify()

    ret_if is_nil(mf), do: {:no_microformat, html}

    {:ok, mf}
  end

  def perform(
        url: url,
        check_mention: check_mention,
        save_mention: save_mention,
        notify_update: notify_update
      ) do
    Timber.add_context(que: %{job_id: Logger.metadata()[:job_id]})

    case fetch(url, check_mention: check_mention) do
      {:ok, mf} ->
        if author = Convert.as_one(mf["author"]) do
          author_url =
            cond do
              is_map(author) -> Convert.as_one(author["url"])
              is_binary(author) -> author
              true -> nil
            end

          if author_url and is_binary(author_url) and
               String.starts_with?(author_url, "http") do
            Que.add(__MODULE__,
              url: author_url,
              check_mention: nil,
              save_mention: nil,
              notify_update: notify_update
            )
          end
        end

        Memento.transaction!(fn ->
          post = Post.from_map(mf)

          if post.url != url,
            do:
              Logger.warn("URL mismatch '#{post.url}' vs #{url}",
                event: %{fetch_url_mismatch: %{post: post.url, requested: url}}
              )

          Memento.Query.write(%{post | url: url})

          if !is_nil(save_mention) do
            post = Memento.Query.read(Post, save_mention)

            props =
              Map.update(post.props, "comment", [url], fn comm ->
                if url in comm, do: comm, else: comm ++ [url]
              end)

            Memento.Query.write(%{post | props: props})
          end
        end)

      {:gone, _} ->
        Memento.transaction!(fn ->
          post = Memento.Query.read(Post, url)

          if post do
            Memento.Query.write(%{post | deleted: true})
          end

          if !is_nil(save_mention) do
            post = Memento.Query.read(Post, save_mention)

            props =
              Map.update(post.props, "comment", [], fn comm ->
                Enum.filter(comm, &(&1 != url))
              end)

            Memento.Query.write(%{post | props: props})
          end
        end)

      {:no_mention, _} ->
        if !is_nil(save_mention) do
          Memento.transaction!(fn ->
            post = Memento.Query.read(Post, save_mention)

            props =
              Map.update(post.props, "comment", [], fn comm ->
                Enum.filter(comm, &(&1 != url))
              end)

            Memento.Query.write(%{post | props: props})
          end)
        end
    end

    Events.notify_urls_updated(notify_update)
  end
end
