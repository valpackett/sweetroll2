defmodule Sweetroll2.Job.Generate do
  @concurrency 8
  @default_dir "out"

  require Logger
  alias Sweetroll2.{Post, Render}
  use Que.Worker

  def dir(), do: System.get_env("SR2_STATIC_GEN_OUT_DIR") || @default_dir

  def can_generate(url, posts, urls_dyn) when is_map(posts) do
    {durl, _} = if Map.has_key?(urls_dyn, url), do: urls_dyn[url], else: {url, nil}

    cond do
      !String.starts_with?(durl, "/") -> :nonlocal
      !Map.has_key?(posts, durl) -> :nonexistent
      !("*" in (posts[durl].acl || ["*"])) -> :nonpublic
      true -> :ok
    end
  end

  defp render_post(opts) do
    Render.render_post(opts)
  rescue
    e -> {:error, e}
  end

  def gen_page(url, posts, urls_dyn) when is_map(posts) do
    path_dir = Path.join(dir(), url)
    {durl, params} = if Map.has_key?(urls_dyn, url), do: urls_dyn[url], else: {url, %{}}

    with {_, {:safe, data}} <-
           {:render,
            render_post(
              post: posts[durl],
              params: params,
              posts: posts,
              # all URLs is fine
              local_urls: Map.keys(posts),
              logged_in: false
            )},
         {_, :ok} <- {:mkdirp, File.mkdir_p(path_dir)},
         {_, :ok} <- {:write, File.write(Path.join(path_dir, "index.html"), data)},
         _ = Logger.info("generated #{url} -> #{Path.join(path_dir, "index.html")}"),
         do: {:ok, url},
         else:
           (e ->
              Logger.error("could not generate #{url}: #{inspect(e)}")
              {:error, url, e})
  end

  def gen_allowed_pages(urls, posts) when is_map(posts) do
    urls_local = Post.urls_local()
    urls_dyn = Post.DynamicUrls.dynamic_urls(posts, urls_local)
    allowed_urls = urls |> Enum.filter(&(can_generate(&1, posts, urls_dyn) == :ok))

    (allowed_urls ++ Map.keys(urls_dyn))
    |> Task.async_stream(&gen_page(&1, posts, urls_dyn), max_concurrency: @concurrency)
    |> Stream.map(fn {:ok, x} -> x end)
    |> Enum.group_by(&elem(&1, 0))
  end

  def perform(urls: urls) do
    posts = Map.new(Memento.transaction!(fn -> Memento.Query.all(Post) end), &{&1.url, &1})

    if urls == :all do
      gen_allowed_pages(Map.keys(posts), posts)
    else
      gen_allowed_pages(urls, posts)
    end
  end
end
