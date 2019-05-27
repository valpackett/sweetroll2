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

  defp lookup_property(%__MODULE__{props: props}, prop), do: props[prop]

  defp lookup_property(x, prop) when is_map(x) do
    x[prop] || x["properties"][prop] || x[:properties][prop] || x["props"][prop] ||
      x[:props][prop]
  end

  defp lookup_property(_, _), do: false

  defp compare_property(x, prop, url) when is_bitstring(prop) and is_bitstring(url) do
    lookup_property(x, prop)
    |> Convert.as_many()
    |> Enum.any?(fn val ->
      url && val &&
        (val == url || URI.parse(val) == URI.merge(Sweetroll2.our_host(), URI.parse(url)))
    end)
  end

  def inline_comments(doc = %__MODULE__{url: url, props: props}, preload) do
    Logger.debug("inline comments: working on #{url}")

    comments =
      props["comment"]
      |> Convert.as_many()
      |> Enum.map(fn
        u when is_bitstring(u) ->
          Logger.debug("inline comments: inlining #{u}")
          preload[u]

        x ->
          x
      end)

    Map.put(doc, :props, Map.put(props, "comment", comments))
  end

  def inline_comments(doc_url, preload) when is_bitstring(doc_url) do
    Logger.debug("inline comments: loading #{doc_url}")
    res = preload[doc_url]
    if res != doc_url, do: inline_comments(res, preload), else: res
  end

  def inline_comments(x, _), do: x

  @doc """
  Splits "comments" (saved webmentions) by post type.

  Requires entries to be maps (does not load urls from the database).

  Lists are reversed.
  """
  def separate_comments(doc = %__MODULE__{url: url, props: %{"comment" => comments}})
      when is_list(comments) do
    Enum.reduce(comments, %{}, fn x, acc ->
      cond do
        # TODO reacji
        compare_property(x, "in-reply-to", url) -> Map.update(acc, :replies, [x], &[x | &1])
        compare_property(x, "like-of", url) -> Map.update(acc, :likes, [x], &[x | &1])
        compare_property(x, "repost-of", url) -> Map.update(acc, :reposts, [x], &[x | &1])
        compare_property(x, "bookmark-of", url) -> Map.update(acc, :bookmarks, [x], &[x | &1])
        compare_property(x, "quotation-of", url) -> Map.update(acc, :quotations, [x], &[x | &1])
        true -> acc
      end
    end)
  end

  def separate_comments(doc = %__MODULE__{}), do: %{}
end
