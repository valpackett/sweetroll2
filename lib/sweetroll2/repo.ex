defmodule Sweetroll2.Repo do
  use Ecto.Repo,
    otp_app: :sweetroll2,
    adapter: Ecto.Adapters.Postgres

  @default_url "postgres://localhost/sweetroll2"

  def init(_, opts) do
    {:ok, Keyword.put(opts, :url, System.get_env("DATABASE_URL") || @default_url)}
  end
end
