import Ecto.Query

defmodule Conv do
  def simplify(%{"properties" => props, "type" => type}) when is_map(props) do
    props
    |> Enum.map(&simplify/1)
    |> Enum.into(%{})
    |> Map.merge(%{type: List.first(type || [])})
  end
  def simplify(map) when is_map(map) do
    map
    |> Enum.map(&simplify/1)
    |> Enum.into(%{})
  end
  def simplify({k, [v]}), do: {String.to_atom(k), simplify(v)}
  def simplify({k, vs}) when is_list(vs), do: {String.to_atom(k), Enum.map(vs, &simplify/1)}
  def simplify({k, v}), do: {String.to_atom(k), simplify(v)}
  def simplify(x), do: x

  def convert(%{type: type, props: props, acl: acl, deleted: deleted}) do
    host = System.get_env("OLD_HOST") || "https://ruunvald.lan"

    if !is_bitstring(List.first(props["url"])) do
      []
    else
      params = props
              |> Enum.map(&simplify/1)
              |> Enum.into(%{})
              |> Map.merge(%{
                type: List.first(type),
                url: String.replace_leading(List.first(props["url"]), host, ""),
                acl: acl,
                deleted: deleted,
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
|> Enum.each(&Sweetroll2.Repo.insert/1)
