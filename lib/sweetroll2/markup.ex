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
    # the cdata thing is basically before_scrub from the sanitizer
    case html |> String.replace("<![CDATA[", "") |> Floki.parse() do
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

  @doc """
  Sanitize untrusted HTML trees (fetched posts in contexts).
  """
  def sanitize_tree(tree),
    do: HtmlSanitizeEx.Traverser.traverse(tree, HtmlSanitizeEx.Scrubber.MarkdownHTML)

  @langs RustledSyntect.supported_langs()
         |> Stream.flat_map(fn %RustledSyntect.Syntax{file_extensions: exts, name: name} ->
           Enum.map(exts, fn e -> {e, name} end)
         end)
         |> Stream.concat([{"ruby", "Ruby"}, {"python", "Python"}, {"haskell", "Haskell"}])
         |> Map.new()

  @doc """
  Apply syntax highlighting to pre>code blocks that have known languages as classes.
  """
  def highlight_code({"pre", p_attrs, {"code", c_attrs, content}}) do
    hl_lang =
      Stream.concat(klasses(p_attrs), klasses(c_attrs))
      |> Enum.find(nil, fn l -> @langs[l] end)

    if hl_lang do
      # TODO: make RustledSyntect produce a parsed tree
      code_tree =
        content
        |> src_text
        |> String.split("\n")
        |> RustledSyntect.hilite_stream(lang: @langs[hl_lang])
        |> Enum.into([])
        |> List.flatten()
        |> Enum.join("")
        |> html_part_to_tree

      {"pre", add_klass(p_attrs, "syntect"), {"code", c_attrs, code_tree}}
    else
      {"pre", p_attrs, {"code", c_attrs, content}}
    end
  end

  def highlight_code({"pre", attrs, content}) when is_list(content) do
    highlight_code(
      {"pre", attrs,
       Enum.find(content, nil, fn
         {"code", _, _} -> true
         _ -> false
       end)}
    )
  end

  def highlight_code({tag, attrs, content}), do: {tag, attrs, highlight_code(content)}

  def highlight_code(l) when is_list(l), do: Enum.map(l, &highlight_code/1)

  def highlight_code(non_tag), do: non_tag

  @doc """
  Render tags like photo-here[id=something] inline from a map of properties
  using provided templates (renderers).
  """
  def inline_media_into_content({tag, attrs, content}, renderers, props)
      when is_bitstring(tag) and is_list(attrs) do
    if String.ends_with?(tag, "-here") do
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
    else
      {tag, attrs, inline_media_into_content(content, renderers, props)}
    end
  end

  def inline_media_into_content(l, renderers, props) when is_list(l),
    do: Enum.map(l, fn child -> inline_media_into_content(child, renderers, props) end)

  def inline_media_into_content(non_tag, _renderers, _props), do: non_tag

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

  defp klasses(attrs) do
    c =
      Stream.filter(attrs, fn
        {"class", _} -> true
        _ -> false
      end)
      |> Enum.map(fn {"class", c} -> c end)
      |> List.first()

    String.split(c || "", ~r/\s+/)
  end

  defp add_klass(attrs, val) do
    if Enum.find(attrs, nil, fn
         {"class", _} -> true
         _ -> false
       end) do
      Enum.map(attrs, fn
        {"class", c} -> {"class", "#{val} #{c}"}
        x -> x
      end)
    else
      attrs ++ [{"class", val}]
    end
  end

  defp src_text({_tag, _attrs, content}), do: src_text(content)
  defp src_text(s) when is_bitstring(s), do: s
  defp src_text(l) when is_list(l), do: Stream.map(l, &src_text/1) |> Enum.join("")
end
