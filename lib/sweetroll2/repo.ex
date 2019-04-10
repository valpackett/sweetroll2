defmodule Sweetroll2.Repo do
  alias Sweetroll2.Doc
  import Ecto.Query

  use Ecto.Repo,
    otp_app: :sweetroll2,
    adapter: Ecto.Adapters.Postgres

  @default_url "postgres://localhost/sweetroll2"

  def init(_, opts) do
    {:ok, Keyword.put(opts, :url, System.get_env("DATABASE_URL") || @default_url)}
  end

  def doc_by_url(url), do: one(from d in Doc, where: d.url == ^url, select: d)

  def docs_all do
    all(from d in Doc, select: d)
    |> Map.new(fn doc -> {doc.url, doc} end)
  end

  def urls_local, do: all(from d in Doc, where: fragment("ascii(url) = 47"), select: d.url)
end
