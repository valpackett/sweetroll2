defmodule Sweetroll2.Doc do
  use Ecto.Schema
  import Ecto.Changeset
  alias Sweetroll2.{Convert}

  @primary_key {:url, :string, []}

  schema "docs" do
    field :type, :string
    field :deleted, :boolean
    field :published, :utc_datetime
    field :updated, :utc_datetime
    field :acl, {:array, :string}
    field :props, :map
    field :children, {:array, :map}
  end

  @real_fields [:url, :type, :deleted, :published, :updated, :acl, :children]

  def atomize_real_key({"url", v}), do: {:url, v}
  def atomize_real_key({"type", v}), do: {:type, v}
  def atomize_real_key({"deleted", v}), do: {:deleted, v}
  def atomize_real_key({"published", v}), do: {:published, v}
  def atomize_real_key({"updated", v}), do: {:updated, v}
  def atomize_real_key({"acl", v}), do: {:acl, v}
  def atomize_real_key({"children", v}), do: {:children, v}
  def atomize_real_key({k, v}), do: {k, v}

  def changeset(struct, params) do
    {allowed, others} = params |> Map.new(&atomize_real_key/1) |> Map.split(@real_fields)
    params = Map.put(allowed, :props, others)

    struct
    |> cast(params, [:props | @real_fields])
    |> validate_required([:url, :type, :published])
  end

  def to_map(%__MODULE__{
        props: props,
        url: url,
        type: type,
        deleted: deleted,
        published: published,
        updated: updated,
        acl: acl,
        children: children
      }) do
    props
    |> Map.put("url", url)
    |> Map.put("type", type)
    |> Map.put("deleted", deleted)
    |> Map.put("published", published)
    |> Map.put("updated", updated)
    |> Map.put("acl", acl)
    |> Map.put("children", children)
  end

  def matches_filter?(doc = %__MODULE__{}, filter) do
    Enum.all?(filter, fn {k, v} ->
      docv = Convert.as_many(doc.props[k])
      Enum.all?(Convert.as_many(v), &Enum.member?(docv, &1))
    end)
  end

  def matches_filters?(doc = %__MODULE__{}, filters) do
    Enum.any?(filters, &matches_filter?(doc, &1))
  end

  def in_feed?(doc = %__MODULE__{}, feed = %__MODULE__{}) do
    matches_filters?(doc, Convert.as_many(feed.props["filter"])) and
      not matches_filters?(doc, Convert.as_many(feed.props["unfilter"]))
  end

  def filter_feeds(urls, preload) do
    Stream.filter(urls, fn url ->
      String.starts_with?(url, "/") && preload[url] && preload[url].type == "x-dynamic-feed"
    end)
  end

  def filter_feed_entries(doc = %__MODULE__{type: "x-dynamic-feed"}, preload, allu) do
    Stream.filter(allu, &(String.starts_with?(&1, "/") and in_feed?(preload[&1], doc)))
    |> Enum.sort(&(DateTime.compare(preload[&1].published, preload[&2].published) == :gt))

    # TODO rely on sorting from repo (should be sorted in Generate too)
  end

  def feed_page_count(entries) do
    # TODO get per_page from feed settings
    ceil(Enum.count(entries) / Application.get_env(:sweetroll2, :entries_per_page, 10))
  end

  def page_url(url, 0), do: url
  def page_url(url, page), do: String.replace_leading("#{url}/page#{page}", "//", "/")

  def dynamic_urls_for(doc = %__MODULE__{type: "x-dynamic-feed"}, preload, allu) do
    cnt = feed_page_count(filter_feed_entries(doc, preload, allu))
    Map.new(1..cnt, &{page_url(doc.url, &1), {doc.url, %{page: &1}}})
  end

  # TODO def dynamic_urls_for(doc = %__MODULE__{type: "x-dynamic-tag-feed"}, preload, allu) do end

  def dynamic_urls_for(_, _, _), do: %{}

  def dynamic_urls(preload, allu) do
    Stream.map(allu, &dynamic_urls_for(preload[&1], preload, allu))
    |> Enum.reduce(&Map.merge/2)
  end
end
