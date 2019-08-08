defmodule Sweetroll2.Micropub do
  @behaviour PlugMicropub.HandlerBehaviour

  require Logger
  alias Sweetroll2.{Auth.Bearer, Auth.AccessToken, Events, Post, Job}
  import Sweetroll2.Convert

  @impl true
  def handle_create(type, properties, token) do
    if Bearer.is_allowed?(token, :create) do
      cat = category_for(properties)
      url = as_one(properties["url"]) || "/#{cat}/#{slug_for(properties)}"

      properties = Map.update(properties, "category", ["_" <> cat], &["_" <> cat | &1])

      clid = AccessToken.get_client_id(token)

      properties = if !is_nil(clid), do: Map.put(properties, "client-id", clid), else: properties

      params = %{type: type, properties: properties, url: url}

      result =
        Memento.transaction!(fn ->
          old_post = Memento.Query.read(Post, url)

          if is_nil(old_post) or old_post.deleted do
            %{Post.from_map(params) | acl: ["*"]}
            |> Map.update(:published, DateTime.utc_now(), &(&1 || DateTime.utc_now()))
            |> Memento.Query.write()

            {:ok, :created, url}
          else
            Logger.error("micropub: url already exists '#{url}'")
            {:error, :invalid_request, :url_exists}
          end
        end)

      case result do
        {:ok, :created, url} ->
          ctxs = Post.contexts_for(properties)
          fetch_contexts(ctxs, url: url)
          Events.notify_urls_updated([url])
          {:ok, :created, url}

        x ->
          x
      end
    else
      {:error, :insufficient_scope, :unauthorized}
    end
  end

  @impl true
  def handle_update(url, replace, add, delete, token) do
    if Bearer.is_allowed?(token, :update) do
      url = read_url(url)

      {removed_ctxs, ctxs} =
        Memento.transaction!(fn ->
          post = Memento.Query.read(Post, url)

          # We want to e.g. notify posts that aren't mentioned anymore too
          old_ctxs = Post.contexts_for(post.props)

          props =
            Enum.reduce(replace, post.props, fn {k, v}, props ->
              Map.put(props, k, v)
            end)

          props =
            Enum.reduce(add, props, fn {k, v}, props ->
              Map.update(props, k, v, &(&1 ++ v))
            end)

          props =
            Enum.reduce(delete, props, fn
              {k, v}, props ->
                if Map.has_key?(props, k) do
                  Map.update!(props, k, &(&1 -- v))
                else
                  props
                end

              k, props ->
                Map.delete(props, k)
            end)

          ctxs = Post.contexts_for(props)
          removed_ctxs = MapSet.difference(old_ctxs, ctxs)

          Memento.Query.write(%{post | props: props, updated: DateTime.utc_now()})

          {removed_ctxs, ctxs}
        end)

      fetch_contexts(ctxs, url: url)
      Events.notify_urls_updated([url])

      full_url = Process.get(:our_home_url) <> url
      # TODO: use backups instead of calculating here
      for target <- removed_ctxs do
        Que.add(Job.SendWebmentions, source: full_url, target: target)
      end

      :ok
    else
      {:error, :insufficient_scope, :unauthorized}
    end
  end

  @impl true
  def handle_delete(url, token) do
    if Bearer.is_allowed?(token, :delete) do
      url = read_url(url)

      Memento.transaction!(fn ->
        post = Memento.Query.read(Post, url)
        Memento.Query.write(%{post | deleted: true})
      end)

      Events.notify_urls_updated([url])

      :ok
    else
      {:error, :insufficient_scope, :unauthorized}
    end
  end

  @impl true
  def handle_undelete(url, token) do
    if Bearer.is_allowed?(token, :undelete) do
      url = read_url(url)

      Memento.transaction!(fn ->
        post = Memento.Query.read(Post, url)
        Memento.Query.write(%{post | deleted: false})
      end)

      Events.notify_urls_updated([url])

      :ok
    else
      {:error, :insufficient_scope, :unauthorized}
    end
  end

  @impl true
  def handle_config_query(token) do
    if Bearer.is_allowed?(token) do
      {:ok, %{}}
    else
      {:error, :insufficient_scope, :unauthorized}
    end
  end

  @impl true
  def handle_source_query(url, _filter_properties, token) do
    # TODO: filter properties
    # XXX: duplication of Serve/get_ logic
    if Bearer.is_allowed?(token) do
      url = read_url(url)
      urls_local = Post.urls_local()
      posts = %Post.DbAsMap{}

      cond do
        !(url in urls_local) ->
          {:error, :insufficient_scope, :not_local}

        !("*" in (posts[url].acl || ["*"])) ->
          {:error, :insufficient_scope, :not_allowed}

        posts[url].deleted ->
          {:error, :insufficient_scope, :deleted}

        true ->
          {:ok, Post.to_full_map(posts[url])}
      end
    else
      {:error, :insufficient_scope, :unauthorized}
    end
  end

  @impl true
  def handle_syndicate_to_query(token) do
    if Bearer.is_allowed?(token) do
      {:ok, []}
    else
      {:error, :insufficient_scope, :unauthorized}
    end
  end

  # TODO
  @impl true
  def handle_media(file, token) do
    if Bearer.is_allowed?(token, :media) do
      {:error, :insufficient_scope, :not_implemented}
    else
      {:error, :insufficient_scope, :unauthorized}
    end
  end

  defp read_url(url) do
    new_url = String.replace_prefix(url, Process.get(:our_home_url), "")

    Logger.info("micropub: url '#{url}' -> '#{new_url}'")
    new_url
  end

  defp slug_for(properties) do
    custom = as_one(properties["mp-slug"] || properties["slug"])

    if is_bitstring(custom) && String.length(custom) > 5 do
      custom
    else
      name = as_one(properties["name"])

      if is_bitstring(name) && String.length(name) > 5 do
        Slugger.slugify(name)
      else
        to_string(DateTime.utc_now()) |> String.replace(" ", "-")
      end
    end
  end

  defp category_for(%{"rating" => x}) when is_list(x) and length(x) != 0, do: "reviews"
  defp category_for(%{"item" => x}) when is_list(x) and length(x) != 0, do: "reviews"
  defp category_for(%{"ingredient" => x}) when is_list(x) and length(x) != 0, do: "recipes"
  defp category_for(%{"name" => x}) when is_list(x) and length(x) != 0, do: "articles"
  defp category_for(%{"in-reply-to" => x}) when is_list(x) and length(x) != 0, do: "replies"
  defp category_for(%{"like-of" => x}) when is_list(x) and length(x) != 0, do: "likes"
  defp category_for(%{"repost-of" => x}) when is_list(x) and length(x) != 0, do: "reposts"
  defp category_for(%{"quotation-of" => x}) when is_list(x) and length(x) != 0, do: "quotations"
  defp category_for(%{"bookmark-of" => x}) when is_list(x) and length(x) != 0, do: "bookmarks"
  defp category_for(%{"rsvp" => x}) when is_list(x) and length(x) != 0, do: "rsvp"
  defp category_for(_), do: "notes"

  defp fetch_contexts(ctxs, url: url) do
    for ctx_url <- ctxs do
      Que.add(Job.Fetch,
        url: ctx_url,
        check_mention: nil,
        save_mention: nil,
        notify_update: [url]
      )
    end
  end
end
