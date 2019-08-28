defmodule Sweetroll2.Post do
  @moduledoc """
  A Mnesia table for storing microformats2 style posts.

  Fields and conventions:

  - `type` is the mf2 type without the `h-` prefix, and each entry has one type
    (practically there was no need for multiple types ever in sweetroll 1)
  - `props` are the "meat" of the post, the mf2 properties (with string keys) expect the special ones:
  - `url` is extracted because it's the primary key
  - `published` and `updated` are extracted for storage as DateTime records instead of text
  """

  import Sweetroll2.Convert
  require Logger

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
      |> Stream.map(fn post ->
        %{post | url: Enum.reduce(local_domains, post.url, &String.replace_prefix(&2, &1, ""))}
      end)
      |> Enum.each(&Memento.Query.write/1)
    end)
  end

  @doc """
  Converts an mf2/jf2 map to a Post struct.

  Keys can be either strings or atoms on the top level.
  Should be strings inside properties though
  (we don't touch it here and the rest of the system expects strings).
  """
  def from_map(map) do
    url = map_prop(map, "url", :url)

    published =
      case DateTimeParser.parse_datetime(map_prop(map, "published", :published), assume_utc: true) do
        {:ok, d} ->
          d

        {:error, e} ->
          Logger.warn(
            "could not parse published: '#{inspect(map_prop(map, "published", :published))}'",
            event: %{date_parse_failed: %{prop: "published", map: map}}
          )

          nil
      end

    updated =
      case DateTimeParser.parse_datetime(map_prop(map, "updated", :updated), assume_utc: true) do
        {:ok, d} ->
          d

        {:error, e} ->
          Logger.warn("could not parse updated: '#{inspect(map_prop(map, "updated", :updated))}'",
            event: %{date_parse_failed: %{prop: "updated", map: map}}
          )

          nil
      end

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
          |> Map.delete("tsv")
          |> Map.delete(:tsv)
        )
        |> Map.delete("url")
        |> Map.delete(:url)
        |> Map.delete("published")
        |> Map.delete(:published)
        |> Map.delete("updated")
        |> Map.delete(:updated),
      url: if(is_binary(url), do: url, else: "___WTF"),
      type: String.replace_prefix(as_one(map["type"] || map[:type]), "h-", ""),
      deleted: map["deleted"] || map[:deleted],
      published: published,
      updated: updated,
      acl: map["acl"] || map[:acl],
      children: map["children"] || map[:children]
    }
  end

  @doc """
  Converts a Post struct to a "simplified" (jf2-ish) map.
  """
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
    |> add_dates(published: published, updated: updated)
    |> Map.put("url", url)
    |> Map.put("type", type)
    |> Map.put("deleted", deleted)
    |> Map.put("acl", acl)
    |> Map.put("children", children)
  end

  def to_map(x) when is_map(x), do: x

  @doc """
  Converts a Post struct to a "full" (mf2-source-ish) map.
  """
  def to_full_map(%__MODULE__{
        props: props,
        url: url,
        type: type,
        # deleted: deleted,
        published: published,
        updated: updated,
        acl: acl,
        children: children
      }) do
    props =
      props
      |> add_dates(published: published, updated: updated)
      |> Map.put("url", url)
      |> Map.put("acl", acl)

    %{
      type: as_many("h-" <> type),
      properties: for({k, v} <- props, into: %{}, do: {k, as_many(v)}),
      children: children
    }
  end

  def to_full_map(x) when is_map(x), do: x

  defp add_dates(props, published: published, updated: updated) do
    props
    |> (fn x ->
          if published, do: Map.put(x, "published", DateTime.to_iso8601(published)), else: x
        end).()
    |> (fn x -> if updated, do: Map.put(x, "updated", DateTime.to_iso8601(updated)), else: x end).()
  end

  defp map_prop(map, prop_str, prop_atom) do
    as_one(
      map[prop_str] || map[prop_atom] ||
        map["properties"][prop_str] || map[:properties][prop_atom]
    )
  end

  def as_url(s) when is_bitstring(s), do: s
  def as_url(m) when is_map(m), do: map_prop(m, "url", :url)

  def contexts_for(props) do
    (as_many(props["in-reply-to"]) ++
       as_many(props["like-of"]) ++
       as_many(props["repost-of"]) ++
       as_many(props["quotation-of"]) ++ as_many(props["bookmark-of"]))
    |> Enum.map(&as_url/1)
    |> MapSet.new()
  end

  def filter_type(urls, posts, type) when is_binary(type) do
    Stream.filter(urls, fn url ->
      posts[url] && posts[url].type == type && !(posts[url].deleted || false) &&
        String.starts_with?(url, "/")
    end)
  end

  def filter_type(urls, posts, types) when is_list(types) do
    Stream.filter(urls, fn url ->
      posts[url] && Enum.any?(types, &(posts[url].type == &1)) && !(posts[url].deleted || false) &&
        String.starts_with?(url, "/")
    end)
  end
end
