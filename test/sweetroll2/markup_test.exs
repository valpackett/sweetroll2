defmodule Sweetroll2.MarkupTest do
  use ExUnit.Case, async: true
  import Sweetroll2.Markup
  doctest Sweetroll2.Markup

  defp test_photo_render(%{"value" => val}), do: {:safe, "Photo{#{val}}"}

  defp i_m_i_c(html, r, p), do: html |> html_part_to_tree |> inline_media_into_content(r, p) |> render_tree

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
      expect = ~S(<div class=sweetroll2-error>Media embedding failed.<pre>{:media_id, "photo", "VOID", nil}</pre></div>)
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
