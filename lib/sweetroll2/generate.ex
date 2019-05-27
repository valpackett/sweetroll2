defmodule Sweetroll2.Generate do
  @concurrency 8
  @default_dir "out"

  require Logger
  alias Sweetroll2.{Doc, Render}

  def dir(), do: System.get_env("OUT_DIR") || @default_dir

  def can_generate(url, preload) do
    cond do
      !String.starts_with?(url, "/") -> :nonlocal
      !Map.has_key?(preload, url) -> :nonexistent
      !("*" in preload[url].acl) -> :nonpublic
      true -> :ok
    end
  end

  defp render_doc(opts) do
    Render.render_doc(opts)
  rescue
    e -> {:error, e}
  end

  def gen_page(url, preload, urls_dyn) do
    path_dir = Path.join(dir(), url)
    {durl, params} = if Map.has_key?(urls_dyn, url), do: urls_dyn[url], else: {url, %{}}

    with {_, {:safe, data}} <-
           {:render,
            render_doc(
              doc: preload[durl],
              params: params,
              preload: preload,
              allu: Map.keys(preload)
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

  def gen_allowed_pages(urls, preload) do
    allowed_urls = urls |> Enum.filter(&(can_generate(&1, preload) == :ok))
    urls_dyn = Doc.dynamic_urls(preload, allowed_urls)

    (allowed_urls ++ Map.keys(urls_dyn))
    |> Task.async_stream(&gen_page(&1, preload, urls_dyn), max_concurrency: @concurrency)
    |> Stream.map(fn {:ok, x} -> x end)
    |> Enum.group_by(&elem(&1, 0))
  end

  def gen_all_allowed_pages(preload) do
    gen_allowed_pages(Map.keys(preload), preload)
  end

  # def perform(%{"type" => "generate", "urls" => urls}) do
  #   preload = Map.new(Memento.transaction!(fn -> Memento.Query.all(Doc) end), &{&1.url, &1})
  #   gen_allowed_pages(urls, preload)
  # end
end
