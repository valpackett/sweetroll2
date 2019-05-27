defmodule Sweetroll2.Generate do
  @concurrency 8
  @default_dir "out"

  require Logger
  alias Sweetroll2.{Post, Render}

  def dir(), do: System.get_env("OUT_DIR") || @default_dir

  def can_generate(url, posts) when is_map(posts) do
    cond do
      !String.starts_with?(url, "/") -> :nonlocal
      !Map.has_key?(posts, url) -> :nonexistent
      !("*" in posts[url].acl) -> :nonpublic
      true -> :ok
    end
  end

  defp render_doc(opts) do
    Render.render_doc(opts)
  rescue
    e -> {:error, e}
  end

  def gen_page(url, posts, urls_dyn) when is_map(posts) do
    path_dir = Path.join(dir(), url)
    {durl, params} = if Map.has_key?(urls_dyn, url), do: urls_dyn[url], else: {url, %{}}

    with {_, {:safe, data}} <-
           {:render,
            render_doc(
              doc: posts[durl],
              params: params,
              posts: posts,
              local_urls: Map.keys(posts) # all URLs is fine
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
    allowed_urls = urls |> Enum.filter(&(can_generate(&1, posts) == :ok))
    urls_dyn = Post.DynamicUrls.dynamic_urls(posts, allowed_urls)

    (allowed_urls ++ Map.keys(urls_dyn))
    |> Task.async_stream(&gen_page(&1, posts, urls_dyn), max_concurrency: @concurrency)
    |> Stream.map(fn {:ok, x} -> x end)
    |> Enum.group_by(&elem(&1, 0))
  end

  def gen_all_allowed_pages(posts) when is_map(posts) do
    gen_allowed_pages(Map.keys(posts), posts)
  end

  # def perform(%{"type" => "generate", "urls" => urls}) do
  #   posts = Map.new(Memento.transaction!(fn -> Memento.Query.all(Post) end), &{&1.url, &1})
  #   gen_allowed_pages(urls, posts)
  # end
end
