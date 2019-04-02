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
  deftpl :entry, "tpl/entry.html.eex"
  deftpl :page_entry, "tpl/page_entry.html.eex"

  def render_doc(doc: doc, preload: preload) do
    cond do
      doc.type == "entry" || doc.type == "review" -> page_entry(entry: doc, preload: preload)
      true -> {:error, :unknown_type, doc.type}
    end
  rescue
    e -> {:error, e}
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

  def home(preload) do
    preload["/"] ||
      %Doc{
        url: "/",
        props: %{"name" => "Create an entry at the root URL (/)!"}
      }
  end
end
