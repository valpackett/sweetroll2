defmodule Sweetroll2.Markup do
  @moduledoc """
  Handling of post markup, trusted (local) and untrusted (fetched).
  """

  import Sweetroll2.Convert
  alias Phoenix.HTML, as: PH
  alias Phoenix.HTML.Format, as: PHF

  def render_tree(tree), do: Floki.raw_html(tree)

  @doc """
  Parse a snippet of HTML without html/head/body tags into a tree.
  """
  def html_part_to_tree(html) do
    # html5ever always inserts a skeleton
    case Floki.parse(html) do
      [{"html", _, [{"head", _, _}, {"body", _, [part]}]}] -> part
      [{"html", _, [{"head", _, _}, {"body", _, parts}]}] -> parts
      x -> x
    end
  end

  defp text_to_tree(t), do: t |> PHF.text_to_html() |> PH.safe_to_string() |> html_part_to_tree

  @doc """
  Parse a JSON content object into a tree.
  """
  def content_to_tree(%{"markdown" => md}), do: md |> Earmark.as_html!() |> html_part_to_tree
  def content_to_tree(%{"html" => h}), do: h |> html_part_to_tree
  def content_to_tree(%{"value" => t}), do: t |> text_to_tree
  def content_to_tree(%{"text" => t}), do: t |> text_to_tree
  def content_to_tree(x), do: x |> to_string |> text_to_tree

  defp inline_media_into_elem({tag, attrs, content}, renderers, props)
       when is_bitstring(tag) and is_list(attrs) do
    cond do
      String.ends_with?(tag, "-here") ->
        media_type = String.trim_trailing(tag, "-here")

        with {_, {_, id}} <- {:id_attr, Enum.find(attrs, fn {k, _} -> k == "id" end)},
             {_, _, rend} when is_function(rend, 1) <-
               {:renderer, media_type, renderers[media_type]},
             medias = as_many(props[media_type]),
             {_, _, _, media} when is_map(media) <-
               {:media_id, media_type, id, Enum.find(medias, fn p -> p["id"] == id end)},
             do: media |> rend.() |> PH.safe_to_string() |> html_part_to_tree,
             # TODO: would be amazing to have taggart output to a tree directly
             else:
               (err ->
                  {"div", [{"class", "sweetroll2-error"}],
                   ["Media embedding failed.", {"pre", [], inspect(err)}]})

      is_list(content) ->
        {tag, attrs,
         Enum.map(content, fn child ->
           inline_media_into_elem(child, renderers, props)
         end)}

      true ->
        {tag, attrs, inline_media_into_elem(content, renderers, props)}
    end
  end

  defp inline_media_into_elem(non_tag, _renderers, _props), do: non_tag

  @doc """
  Render tags like photo-here[id=something] inline from a map of properties
  using provided templates (renderers).
  """
  def inline_media_into_content(tree, renderers, props) do
    as_many(tree)
    |> Enum.map(fn elem -> inline_media_into_elem(elem, renderers, props) end)
  end

  @doc """
  Remove media that was inserted by inline_media_into_content from a data property.
  """
  def exclude_inlined_media(tree, media_name, media_items) do
    used_ids =
      Floki.find(tree, "#{media_name}-here")
      |> Enum.map(fn {_, a, _} ->
        {_, id} = Enum.find(a, fn {k, _} -> k == "id" end)
        id
      end)

    Enum.filter(media_items, fn i ->
      is_bitstring(i) or not Enum.member?(used_ids, i["id"])
    end)
  end
end
