defmodule Sweetroll2.Doc do
  use Ecto.Schema
  import Ecto.Changeset

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
        type: type,
        deleted: deleted,
        published: published,
        updated: updated,
        acl: acl,
        children: children
      }) do
    props
    |> Map.put("type", type)
    |> Map.put("deleted", deleted)
    |> Map.put("published", published)
    |> Map.put("updated", updated)
    |> Map.put("acl", acl)
    |> Map.put("children", children)
  end
end
