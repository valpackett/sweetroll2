defmodule Sweetroll2.Post do
  @moduledoc """
  A Mnesia table for storing microformats2 style posts.
  (+ Everything to do with data access. This really should be split up.)

  Fields and conventions:

  - `type` is the mf2 type without the `h-` prefix, and each entry has one type
    (practically there was no need for multiple types ever in sweetroll 1)
  - `props` are the "meat" of the post, the mf2 properties (with string keys) expect the special ones:
  - `url` is extracted because it's the primary key
  - `published` and `updated` are extracted for storage as DateTime records instead of text
  """

  use Memento.Table,
    attributes: [:url, :deleted, :published, :updated, :acl, :type, :props, :children]

  def urls_local do
    :mnesia.dirty_select(__MODULE__, [{:"$1", [], [{:element, 2, :"$1"}]}])
    |> Enum.filter(&String.starts_with?(&1, "/"))
  end

  def import_json_lines(text, local_domains \\ ["http://localhost", "https://localhost"]) do
    Memento.transaction!(fn ->
      text
      |> String.splitter("\n")
      |> Stream.filter(&(String.length(&1) > 1))
      |> Stream.map(&Jason.decode!/1)
      |> Stream.map(&__MODULE__.from_map/1)
      |> Stream.map(fn doc ->
        %{doc | url: Enum.reduce(local_domains, doc.url, &String.replace_prefix(&2, &1, ""))}
      end)
      |> Enum.each(&Memento.Query.write/1)
    end)
  end

  require Logger
  alias Sweetroll2.{Convert}

  def map_prop(map, prop_str, prop_atom) do
    Convert.as_one(
      map[prop_str] || map[prop_atom] ||
        map["properties"][prop_str] || map[:properties][prop_atom]
    )
  end

  def from_iso8601(nil), do: nil

  def from_iso8601(s) when is_binary(s) do
    case DateTime.from_iso8601(s) do
      {:ok, x, _} ->
        x

      {:error, :missing_offset} ->
        from_iso8601(s <> "Z")

      err ->
        Logger.warn("could not parse iso8601: '#{s}' -> #{inspect(err)}")
        nil
    end
  end

  def from_map(map) do
    url = map_prop(map, "url", :url)

    %__MODULE__{
      props:
        (map["properties"] || %{})
        |> Map.merge(map[:properties] || %{})
        |> Map.merge(map["props"] || %{})
        |> Map.merge(map[:props] || %{})
        |> Map.merge(
          map
          |> Map.delete("properties")
          |> Map.delete(:properties)
          |> Map.delete("props")
          |> Map.delete(:props)
          |> Map.delete("type")
          |> Map.delete(:type)
          |> Map.delete("deleted")
          |> Map.delete(:deleted)
          |> Map.delete("acl")
          |> Map.delete(:acl)
          |> Map.delete("children")
          |> Map.delete(:children)
        )
        |> Map.delete("url")
        |> Map.delete(:url)
        |> Map.delete("published")
        |> Map.delete(:published)
        |> Map.delete("updated")
        |> Map.delete(:updated),
      url: if(is_binary(url), do: url, else: "___WTF"),
      type: String.replace_prefix(Convert.as_one(map["type"] || map[:type]), "h-", ""),
      deleted: map["deleted"] || map[:deleted],
      published: from_iso8601(map_prop(map, "published", :published)),
      updated: from_iso8601(map_prop(map, "updated", :updated)),
      acl: map["acl"] || map[:acl],
      children: map["children"] || map[:children]
    }
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
    |> (fn x ->
          if published, do: Map.put(x, "published", DateTime.to_iso8601(published)), else: x
        end).()
    |> (fn x -> if updated, do: Map.put(x, "updated", DateTime.to_iso8601(updated)), else: x end).()
    |> Map.put("url", url)
    |> Map.put("type", type)
    |> Map.put("deleted", deleted)
    |> Map.put("acl", acl)
    |> Map.put("children", children)
  end

  def to_map(x) when is_map(x), do: x

end
