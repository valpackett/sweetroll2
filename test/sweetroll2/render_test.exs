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
          entry: %Sweetroll2.Post{
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

  defp parse_rendered_entry(args) do
    html = safe_to_string(page_entry(args))

    %{items: [%{type: ["h-entry"], properties: props}], rels: rels} =
      Microformats2.parse(html, "http://localhost")

    %{props: props, html: html, rels: rels}
  end
end
