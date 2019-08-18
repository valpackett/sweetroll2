defmodule Sweetroll2.Post.Page do
  alias Sweetroll2.{Post, Convert}
  require Logger

  defdelegate render(tpl, ctx), to: Liquid.Template

  def get_template(%Post{type: "x-custom-page", url: url} = post) do
    ConCache.get_or_store(:parsed_tpl, url, fn ->
      get_template_raw(post)
    end)
  end

  def get_template_raw(%Post{type: "x-custom-page", props: props}) do
    Logger.debug("parsing tpl", event: %{parsing_template: %{props: props}})

    (Convert.as_one(props["content"]) || %{})["html"]
    |> Liquid.Template.parse()
  end

  def clear_cached_template(url: url), do: ConCache.delete(:parsed_tpl, url)

  def used_feeds(%Post{} = post), do: used_feeds(get_template(post))
  def used_feeds(%Liquid.Template{root: root}), do: used_feeds(root)

  def used_feeds(%Liquid.Block{nodelist: nodelist}),
    do: Enum.flat_map(nodelist, &used_feeds/1)

  def used_feeds(%Liquid.Tag{name: :feedpreview, markup: markup}), do: [markup]
  def used_feeds(_), do: []
end
