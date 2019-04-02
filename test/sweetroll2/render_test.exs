defmodule Sweetroll2.RenderTest do
  use ExUnit.Case, async: true
  import Phoenix.HTML
  import Sweetroll2.Render
  doctest Sweetroll2.Render

  describe "page_entry" do
    test "outputs entries" do
      pubdate = DateTime.utc_now()

      %{props: props, html: html} =
        parse_rendered_entry(
          entry: %Sweetroll2.Doc{
            published: pubdate,
            url: "/hello",
            props: %{
              "name" => "Hello World!",
              "content" => %{"markdown" => "*hi* <em>hello</em>"}
            }
          },
          preload: %{}
        )

      assert Enum.uniq(props["url"]) == ["http://localhost/hello"]
      assert props["name"] == ["Hello World!"]
      assert props["content"] == [%{html: "<p><em>hi</em><em>hello</em></p>", text: "hihello"}]
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

  describe "inline_media_into_content" do
    test "inlines photos" do
      photo = %{"id" => "thingy", "value" => "x.jpg"}
      html = "<photo-here id=thingy></photo-here><b>hi</b>"
      expect = safe_to_string(photo_rendered(photo)) <> "<b>hi</b>"
      result = inline_media_into_content(html, photo: [photo], video: [], audio: [])
      assert Floki.parse(result) == Floki.parse(expect)
    end

    test "inlines photos deep in DOM" do
      photo = %{"id" => "thingy", "value" => "y.jpg"}
      html = "<div><div><photo-here id=thingy></photo-here><b>hi</b></div></div>"
      expect = "<div><div>" <> safe_to_string(photo_rendered(photo)) <> "<b>hi</b></div></div>"
      result = inline_media_into_content(html, photo: [photo], video: [], audio: [])
      assert Floki.parse(result) == Floki.parse(expect)
    end

    test "inlines nonexistent photos" do
      html = "<photo-here id=VOID></photo-here>"
      expect = safe_to_string(photo_rendered(nil))
      result = inline_media_into_content(html, photo: [], video: [], audio: [])
      assert Floki.parse(result) == Floki.parse(expect)
    end
  end

  describe "exclude_inlined_media" do
    test "works" do
      tree =
        Floki.parse(
          "<photo-here id=one></photo-here><div><video-here id=vid></video-here><br><photo-here id=two></photo-here></div>"
        )

      assert exclude_inlined_media(tree, "photo", []) == []
      assert exclude_inlined_media(tree, "photo", [%{"id" => "one", "x" => "y"}]) == []
      assert exclude_inlined_media(tree, "photo", [%{"id" => "two", "x" => "y"}]) == []
      assert exclude_inlined_media(tree, "photo", [%{"id" => "three"}]) == [%{"id" => "three"}]

      assert exclude_inlined_media(tree, "video", [%{"id" => "vid"}, %{"a" => "b"}]) == [
               %{"a" => "b"}
             ]

      assert exclude_inlined_media(tree, "video", [%{"id" => "one"}]) == [%{"id" => "one"}]
    end
  end

  defp parse_rendered_entry(args) do
    html = safe_to_string(page_entry(args))

    %{items: [%{type: ["h-entry"], properties: props}], rels: rels} =
      Microformats2.parse(html, "http://localhost")

    %{props: props, html: html, rels: rels}
  end
end
