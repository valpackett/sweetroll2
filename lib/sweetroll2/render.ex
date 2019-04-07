defmodule Sweetroll2.Render.Tpl do
  defmacro deftpl(name, file) do
    quote do
      EEx.function_from_file(:def, unquote(name), unquote(file), [:assigns],
        engine: Phoenix.HTML.Engine
      )
    end
  end
end

defmodule Sweetroll2.Render do
  alias Sweetroll2.Doc
  import Sweetroll2.Convert
  import Sweetroll2.Render.Tpl
  import Phoenix.HTML.Tag
  import Phoenix.HTML
  require EEx

  deftpl :head, "tpl/head.html.eex"
  deftpl :header, "tpl/header.html.eex"
  deftpl :footer, "tpl/footer.html.eex"
  deftpl :entry, "tpl/entry.html.eex"
  deftpl :cite, "tpl/cite.html.eex"
  deftpl :page_entry, "tpl/page_entry.html.eex"
  deftpl :page_feed, "tpl/page_feed.html.eex"

  def render_doc(doc: doc, preload: preload) do
    cond do
      doc.type == "entry" || doc.type == "review" -> page_entry(entry: doc, preload: preload)
      doc.type == "x-dynamic-feed" ->
        children = Map.keys(preload)
                   |> Stream.filter(fn url ->
                     String.starts_with?(url, "/") and
                     Doc.in_feed?(preload[url], doc)
                   end)
        page_feed(feed: %{ doc | children: children }, preload: preload)
      true -> {:error, :unknown_type, doc.type}
    end
  end

  def asset(url) do
    "/as/#{url}"
  end

  def icon(data) do
    content_tag :svg,
      role: "image",
      "aria-hidden": if(data[:title], do: "false", else: "true"),
      class: Enum.join([:icon] ++ (data[:class] || []), " "),
      title: data[:title] do
      content_tag :use, "xlink:href": "#{asset("icons.svg")}##{data[:name]}" do
        if data[:title] do
          content_tag :title do
            data[:title]
          end
        end
      end
    end
  end

  def time_permalink(%Doc{published: published, url: url}, rel: rel) do
    use Taggart.HTML

    if published do
      time datetime: DateTime.to_iso8601(published), class: "dt-published" do
        a href: url, class: "u-url u-uid", rel: rel do
          published
        end
      end
    end
  end

  def trim_url_stuff(url) do
    url
    |> String.replace_leading("http://", "")
    |> String.replace_leading("https://", "")
    |> String.replace_trailing("/", "")
  end

  def client_id(clid) do
    use Taggart.HTML

    lnk = as_one(clid)

    a href: lnk, class: "u-client-id" do
      trim_url_stuff(lnk)
    end
  end

  def syndication_name(url) do
    cond do
      String.contains?(url, "indieweb.xyz") -> "Indieweb.xyz"
      String.contains?(url, "news.indieweb.org") -> "IndieNews"
      String.contains?(url, "lobste.rs") -> "lobste.rs"
      String.contains?(url, "news.ycombinator.com") -> "HN"
      String.contains?(url, "twitter.com") -> "Twitter"
      String.contains?(url, "tumblr.com") -> "Tumblr"
      String.contains?(url, "facebook.com") -> "Facebook"
      String.contains?(url, "instagram.com") -> "Instagram"
      String.contains?(url, "swarmapp.com") -> "Swarm"
      true -> trim_url_stuff(url)
    end
  end

  def doc_title(doc) do
    doc.props["name"] || DateTime.to_iso8601(doc.published)
  end

  def content_rendered(cont) do
    case cont do
      %{"markdown" => md} -> raw(Earmark.as_html!(md))
      %{"html" => h} -> raw(h)
      %{"text" => t} -> Phoenix.HTML.Format.text_to_html(t)
      t -> Phoenix.HTML.Format.text_to_html(to_string(t))
    end
  end

  def responsive_container(media, do: body) when is_map(media) do
    use Taggart.HTML

    is_resp = is_integer(media["width"]) && is_integer(media["height"])
    cls = if is_resp, do: "responsive-container", else: ""

    col =
      case as_one(
             Enum.sort_by(media["palette"] || [], fn {_, v} ->
               if is_map(v), do: v["population"], else: 0
             end)
           ) do
        {_, %{"color" => c}} -> c
        _ -> nil
      end

    prv = media["tiny_preview"]

    bcg =
      if col || prv,
        do: "background:#{col || ""} #{if prv, do: "url('#{prv}')", else: ""};",
        else: ""

    pad =
      if is_resp,
        do: "padding-bottom:#{media["height"] / media["width"] * 100}%",
        else: ""

    div(class: cls, style: "#{bcg}#{pad}", do: body)
  end

  def responsive_container(_, do: body), do: body

  def photo_rendered(photo) do
    use Taggart.HTML

    figure class: "entry-photo" do
      responsive_container(photo) do
        cond do
          is_bitstring(photo) ->
            img(class: "u-photo", src: photo, alt: "")

          is_map(photo) && photo["source"] ->
            srcs = as_many(photo["source"])

            default =
              srcs
              |> Stream.filter(&is_map/1)
              |> Enum.sort_by(fn x -> {x["default"] || false, x["type"] != "image/jpeg"} end)
              |> as_one

            content_tag :picture do
              taggart do
                srcs
                |> Stream.filter(fn src -> src != default && !src["original"] end)
                |> Enum.map(fn src ->
                  source(
                    srcset: src["srcset"] || src["src"],
                    media: src["media"],
                    sizes: src["sizes"],
                    type: src["type"]
                  )
                end)

                img(class: "u-photo", src: default["src"], alt: photo["alt"] || "")
              end
            end

          is_map(photo) && is_bitstring(photo["value"]) ->
            img(class: "u-photo", src: photo["value"], alt: photo["alt"] || "")

          true ->
            {:safe, "<!-- no img -->"}
        end
      end
    end
  end

  defp inline_media_into_tag({"photo-here", attrs, _}, photo: photos, video: _, audio: _) do
    {_, id} = Enum.find(attrs, fn {k, _} -> k == "id" end)
    Floki.parse(safe_to_string(photo_rendered(Enum.find(photos, fn p -> p["id"] == id end))))
  end

  defp inline_media_into_tag({t, a, c}, photo: photos, video: videos, audio: audios)
       when is_list(c) do
    {t, a,
     Enum.map(c, fn child ->
       inline_media_into_tag(child, photo: photos, video: videos, audio: audios)
     end)}
  end

  defp inline_media_into_tag(non_tag, photo: _, video: _, audio: _), do: non_tag

  def inline_media_into_content(html, media) when is_bitstring(html),
    do: inline_media_into_content(Floki.parse(html), media)

  def inline_media_into_content(tree, photo: photos, video: videos, audio: audios) do
    as_many(tree)
    |> Enum.map(fn t ->
      inline_media_into_tag(t, photo: photos, video: videos, audio: audios)
    end)
    |> Floki.raw_html()
  end

  def exclude_inlined_media(html, media_name, media_items) when is_bitstring(html),
    do: exclude_inlined_media(Floki.parse(html), media_name, media_items)

  def exclude_inlined_media(tree, media_name, media_items) do
    used_ids =
      Floki.find(tree, "#{media_name}-here")
      |> Enum.map(fn {_, a, _} ->
        {_, id} = Enum.find(a, fn {k, _} -> k == "id" end)
        id
      end)

    Enum.filter(media_items, fn i -> not Enum.member?(used_ids, i["id"]) end)
  end

  def to_cite(url, preload: preload) when is_bitstring(url) do
    if preload[url] do
      preload[url] |> Doc.to_map() |> simplify
    else
      url
    end
  end

  def to_cite(entry, preload: _) when is_map(entry), do: simplify(entry)

  def author(author, preload: _) when is_map(author) do
    use Taggart.HTML

    a href: author["url"], class: "u-author #{if author["name"], do: "h-card", else: ""}" do
      author["name"] || author["url"]
    end
  end

  def author(author, preload: preload) when is_bitstring(author) do
    if preload[author] do
      preload[author] |> Doc.to_map() |> simplify |> author(preload: preload)
    else
      author(%{"url" => author}, preload: preload)
    end
  end

  def home(preload) do
    preload["/"] ||
      %Doc{
        url: "/",
        props: %{"name" => "Create an entry at the root URL (/)!"}
      }
  end
end
