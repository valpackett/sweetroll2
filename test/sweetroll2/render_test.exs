defmodule Sweetroll2.RenderTest do
  use ExUnit.Case, async: true
  import Phoenix.HTML
  import Sweetroll2.Render
  doctest Sweetroll2.Render

  describe "page_entry" do
    test "outputs entries" do
      pubdate = DateTime.utc_now()

      %{props: props, html: _html} =
        parse_rendered_entry(
          entry: %Sweetroll2.Doc{
            published: pubdate,
            url: "/hello",
            props: %{
              "name" => "Hello World!",
              "content" => %{"markdown" => "*hi* <em>hello</em>"}
            }
          },
          preload: %{},
          feed_urls: []
        )

      assert Enum.uniq(props["url"]) == ["http://localhost/hello"]
      assert props["name"] == ["Hello World!"]
      assert props["content"] == [%{html: "<p><em>hi</em> <em>hello</em></p>", text: "hi hello"}]
      assert props["published"] == [DateTime.to_iso8601(pubdate)]
    end
  end

  describe "content_rendered" do
    test "renders markdown" do
      assert safe_to_string(content_rendered(%{"markdown" => "*hi*"})) == "<p><em>hi</em></p>\n"

      assert safe_to_string(content_rendered(%{"markdown" => "*hi*", "html" => "nope"})) ==
               "<p><em>hi</em></p>\n"
    end

    test "uses html" do
      assert safe_to_string(content_rendered(%{"html" => "<em>hi</em>"})) == "<em>hi</em>"

      assert safe_to_string(content_rendered(%{"html" => "<em>hi</em>", "text" => "nope"})) ==
               "<em>hi</em>"
    end

    test "uses text" do
      assert safe_to_string(content_rendered(%{"text" => "<em>hi</em>"})) ==
               "<p>&lt;em&gt;hi&lt;/em&gt;</p>\n"

      assert safe_to_string(content_rendered(%{"text" => "<em>hi</em>", "xxx" => "whatever"})) ==
               "<p>&lt;em&gt;hi&lt;/em&gt;</p>\n"

      assert safe_to_string(content_rendered("<em>hi</em>")) == "<p>&lt;em&gt;hi&lt;/em&gt;</p>\n"
    end
  end

  defp parse_rendered_entry(args) do
    html = safe_to_string(page_entry(args))

    %{items: [%{type: ["h-entry"], properties: props}], rels: rels} =
      Microformats2.parse(html, "http://localhost")

    %{props: props, html: html, rels: rels}
  end
end
