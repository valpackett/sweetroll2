import Ecto.Query

defmodule Conv do
  def convert(%{type: type, props: props, acl: acl, deleted: deleted}) do
    host = System.get_env("OLD_HOST") || "https://ruunvald.lan"

    if !is_bitstring(List.first(props["url"])) do
      []
    else
      params = props
              |> Enum.map(&Sweetroll2.Convert.simplify/1)
              |> Enum.into(%{})
              |> Map.merge(%{
                type: String.replace_prefix(List.first(type), "h-", ""),
                url: String.replace_leading(List.first(props["url"]), host, ""),
                acl: acl,
                deleted: deleted,
                published: List.first(props["published"] || []),
                updated: List.first(props["updated"] || []),
              })
      [Sweetroll2.Doc.changeset(%Sweetroll2.Doc{}, params)]
    end
  end
end

defmodule OldRepo do
  use Ecto.Repo,
    otp_app: :who_cares,
    adapter: Ecto.Adapters.Postgres

  @default_url "postgres://localhost/sweetroll"

  def init(_, opts) do
    {:ok, Keyword.put(opts, :url, System.get_env("OLD_DATABASE_URL") || @default_url)}
  end
end

OldRepo.start_link
Sweetroll2.Repo.start_link

(from u in "objects", prefix: "mf2", select: %{type: u.type, props: u.properties, acl: u.acl, deleted: u.deleted})
|> OldRepo.all
|> Enum.flat_map(&Conv.convert/1)
|> Enum.each(fn x -> Sweetroll2.Repo.insert(x, on_conflict: :replace_all, conflict_target: :url) end)
