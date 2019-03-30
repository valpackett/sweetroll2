defmodule Sweetroll2.Repo do
  import Ecto.Query

  use Ecto.Repo,
    otp_app: :sweetroll2,
    adapter: Ecto.Adapters.Postgres

  @default_url "postgres://localhost/sweetroll2"

  def init(_, opts) do
    {:ok, Keyword.put(opts, :url, System.get_env("DATABASE_URL") || @default_url)}
  end

  def docs_all() do
    all(from d in Sweetroll2.Doc, select: d)
    |> Map.new(fn doc -> {doc.url, doc} end)
  end
end
