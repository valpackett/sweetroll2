defmodule Sweetroll2.Job.Generate do
  @concurrency 8
  @default_dir "out"

  require Logger
  alias Sweetroll2.{Post, Render, Job.Compress}
  use Que.Worker

  def dir, do: System.get_env("SR2_STATIC_GEN_OUT_DIR") || @default_dir

  def can_generate(url, posts, local_urls) when is_map(posts) do
    cond do
      !String.starts_with?(url, "/") -> :nonlocal
      url not in local_urls -> :nonexistent
      !("*" in (Post.Generative.lookup(url, posts, local_urls).acl || ["*"])) -> :nonpublic
      true -> :ok
    end
  end

  def gen_page(url, posts, local_urls, log_ctx) when is_map(posts) do
    Process.flag(:min_heap_size, 131_072)
    Process.flag(:min_bin_vheap_size, 131_072)
    Process.flag(:priority, :low)
    Timber.LocalContext.save(log_ctx)
    Timber.add_context(sr2_generator: %{url: url})

    path_dir = Path.join(dir(), url)

    {:safe, data} =
      Render.render_post(
        post: Post.Generative.lookup(url, posts, local_urls),
        posts: posts,
        # all URLs is fine
        local_urls: local_urls,
        logged_in: false
      )

    File.mkdir_p!(path_dir)
    path = Path.join(path_dir, "index.html")
    File.write!(path, data)

    Logger.info("generated #{url} -> #{path}",
      event: %{generate_success: %{url: url, path: path}}
    )

    path
  end

  def gen_allowed_pages(urls, posts) when is_map(posts) do
    local_urls = Post.urls_local()
    urls_dyn = Post.Generative.list_generated_urls(local_urls, posts, local_urls)
    all_local_urls = local_urls ++ urls_dyn

    log_ctx = Timber.LocalContext.load()

    if(urls == :all, do: all_local_urls, else: urls)
    |> Enum.filter(&(can_generate(&1, posts, all_local_urls) == :ok))
    |> Task.async_stream(&gen_page(&1, posts, local_urls, log_ctx), max_concurrency: @concurrency)
    |> Enum.group_by(&elem(&1, 0))
  end

  def perform(urls: urls, next_jobs: next_jobs) do
    Process.flag(:min_heap_size, 524_288)
    Process.flag(:min_bin_vheap_size, 524_288)
    Process.flag(:priority, :low)
    Timber.add_context(que: %{job_id: Logger.metadata()[:job_id]})

    posts = Map.new(Memento.transaction!(fn -> Memento.Query.all(Post) end), &{&1.url, &1})

    result = gen_allowed_pages(urls, posts)

    for {:ok, path} <- result.ok do
      Que.add(Compress, path: path)
    end

    for {mod, args} <- next_jobs do
      Que.add(mod, args)
    end
  end

  def remove_generated(url) do
    path_dir = Path.join(dir(), url)
    File.rm(Path.join(path_dir, "index.html"))
    File.rm(Path.join(path_dir, "index.html.gz"))
    File.rm(Path.join(path_dir, "index.html.br"))
  end

  def enqueue_all(next_jobs \\ []) do
    Que.add(__MODULE__, urls: :all, next_jobs: next_jobs)
  end
end
