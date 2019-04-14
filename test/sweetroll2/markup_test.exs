defmodule Sweetroll2.MarkupTest do
  use ExUnit.Case, async: true
  import Sweetroll2.Markup
  doctest Sweetroll2.Markup

  defp s_t(html),
    do: html |> html_part_to_tree |> sanitize_tree |> render_tree

  describe "sanitize_tree" do
    test "removes scripts but not text formatting" do
      # https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/XSS%20Injection
      assert s_t("<b>hi</b> <script>alert('XSS')</script>") == "<b>hi</b> alert(&apos;XSS&apos;)"

      assert s_t("\"><img src=x onerror=alert(String.fromCharCode(88,83,83));>") ==
               ~S[&quot;&gt;<img src="x"/>]

      assert s_t("<video/poster/onerror=alert(1)>") == ""
      assert s_t("#\"><img src=/ onerror=alert(2)>") == ~S[#&quot;&gt;<img src="/"/>]

      assert s_t("-->'\"/></sCript><svG x=\">\" onload=(co\\u006efirm)``>") ==
               "--&gt;&apos;&quot;/&gt;"

      assert s_t("<img/src='1'/onerror=alert(0)>") == ~S[<img src="1"/>]
      assert s_t("<svgonload=alert(1)>") == ""
      assert s_t("<svg onload=alert(1)//") == ""

      assert s_t("<</script/script><script>eval('\\u'+'0061'+'lert(1)')//</script>") ==
               "&lt;eval(&apos;\\u&apos;+&apos;0061&apos;+&apos;lert(1)&apos;)//"

      assert s_t(
               ~S[<img/id="alert&lpar;&#x27;XSS&#x27;&#x29;\"/alt=\"/\"src=\"/\"onerror=eval(id&#x29;>]
             ) == "<img alt='\\\"/\\\"src=\\\"/\\\"onerror=eval(id)'/>"

      assert s_t(~S[<noscript><p title="</noscript><img src=x onerror=alert(1)>">]) ==
               ~S[<img src="x"/>&quot;&gt;]
    end
  end

  defp test_photo_render(%{"value" => val}), do: {:safe, "Photo{#{val}}"}

  defp i_m_i_c(html, r, p),
    do: html |> html_part_to_tree |> inline_media_into_content(r, p) |> render_tree

  describe "inline_media_into_content" do
    test "inlines photos" do
      photo = %{"id" => "thingy", "value" => "x.jpg"}
      html = "<photo-here id=thingy></photo-here><b>hi</b>"
      expect = "Photo{x.jpg}<b>hi</b>"
      result = i_m_i_c(html, %{"photo" => &test_photo_render/1}, %{"photo" => [photo]})
      assert html_part_to_tree(result) == html_part_to_tree(expect)
    end

    test "inlines photos deep in DOM" do
      photo = %{"id" => "thingy", "value" => "y.jpg"}
      html = "<div><div><photo-here id=thingy></photo-here><b>hi</b></div></div>"
      expect = "<div><div>Photo{y.jpg}<b>hi</b></div></div>"
      result = i_m_i_c(html, %{"photo" => &test_photo_render/1}, %{"photo" => [photo]})
      assert html_part_to_tree(result) == html_part_to_tree(expect)
    end

    test "inlines nonexistent photos" do
      html = "<photo-here id=VOID></photo-here>"

      expect =
        ~S(<div class=sweetroll2-error>Media embedding failed.<pre>{:no_media_id, "photo", "VOID", nil}</pre></div>)

      result = i_m_i_c(html, %{"photo" => &test_photo_render/1}, %{"photo" => []})
      assert html_part_to_tree(result) == html_part_to_tree(expect)
    end
  end

  describe "exclude_inlined_media" do
    test "works" do
      tree =
        html_part_to_tree(
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
end
