defmodule Sweetroll2.Doc do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:url, :string, []}

  schema "docs" do
    field :type, :string
    field :deleted, :boolean
    field :published, :utc_datetime
    field :acl, {:array, :string}
    field :props, :map
    field :children, {:array, :map}
  end

  @real_fields [:url, :type, :deleted, :published, :acl, :children]

  def changeset(struct, params) do
    {allowed, others} = Map.split(params, @real_fields)
    params = Map.put(allowed, :props, others)

    struct
    |> cast(params, [:props | @real_fields])
    |> validate_required([:url, :type, :published])
  end

  def to_map(%Sweetroll2.Doc{
        props: props,
        type: type,
        deleted: deleted,
        published: published,
        acl: acl,
        children: children
      }) do
    props
    |> Map.put(:type, type)
    |> Map.put(:deleted, deleted)
    |> Map.put(:published, published)
    |> Map.put(:acl, acl)
    |> Map.put(:children, children)
  end
end
