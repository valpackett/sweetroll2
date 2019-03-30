defmodule Sweetroll2.Generate do
  @concurrency 5
  @default_dir "out"

  def dir(), do: System.get_env("OUT_DIR") || @default_dir

  def can_generate(url, preload) do
    cond do
      !String.starts_with?(url, "/") -> :nonlocal
      !Map.has_key?(preload, url) -> :nonexistent
      !("*" in preload[url].acl) -> :nonpublic
      true -> :ok
    end
  end

  def gen_page(url, preload) do
    {:safe, data} = Sweetroll2.Render.render_doc(doc: preload[url], preload: preload)
    path_dir = Path.join(dir(), url)
    File.mkdir_p!(path_dir)
    File.write!(Path.join(path_dir, "index.html"), data)
  end

  def gen_allowed_pages(urls, preload) do
    urls
    |> Stream.filter(fn url -> can_generate(url, preload) == :ok end)
    |> Task.async_stream(
      fn url ->
        try do
          gen_page(url, preload)
          {:ok, url}
        rescue
          e -> {:err, url, e}
        end
      end,
      max_concurrency: @concurrency
    )
    |> Stream.map(fn {:ok, x} -> x end)
    |> Enum.group_by(fn x -> elem(x, 0) end)
  end

  def gen_all_allowed_pages(preload) do
    gen_allowed_pages(Map.keys(preload), preload)
  end
end
