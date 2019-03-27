defmodule Sweetroll2.Doc do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:url, :string, []}

  schema "docs" do
    field :type, :string
    field :deleted, :boolean
    field :published, :utc_datetime
    field :acl, {:array, :text}
    field :props, :map
    field :children, {:array, :map}
  end

  @real_fields [:url, :type, :deleted, :place_id, :entree_id]

  def changeset(struct, params) do
    {allowed, others} = Map.split(params, @real_fields)
    params = Map.put(allowed, :props, others)

    struct
    |> cast(params, [:props | @real_fields])
  end
end
