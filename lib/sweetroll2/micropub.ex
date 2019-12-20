defmodule Sweetroll2.Micropub do
  @behaviour PlugMicropub.HandlerBehaviour

  require Logger
  import ExEarlyRet
  alias Sweetroll2.{Auth.Bearer, Auth.AccessToken, Events, Post, Markup, MediaUpload, Job}
  import Sweetroll2.Convert

  @impl true
  def handle_create(type, properties, token) do
    if Bearer.is_allowed?(token, :create) do
      {properties, url} =
        if type == "entry" or type == "review" do
          cat = category_for(properties)

          {Map.update(properties, "category", ["_" <> cat], &["_" <> cat | &1]),
           as_one(properties["url"]) || "/#{cat}/#{slug_for(properties)}"}
        else
          {properties, as_one(properties["url"]) || "/__wtf__/#{slug_for(properties)}"}
        end

      clid = AccessToken.get_client_id(token)

      properties =
        if(!is_nil(clid), do: Map.put(properties, "client-id", clid), else: properties)
        |> MediaUpload.replace_all()

      params = %{type: type, properties: properties, url: url}

      result =
        Memento.transaction!(fn ->
          old_post = Memento.Query.read(Post, url)

          if is_nil(old_post) or old_post.deleted do
            Post.from_map(params)
            |> Map.update(:published, DateTime.utc_now(), &(&1 || DateTime.utc_now()))
            |> Map.update(:status, :published, &(&1 || :published))
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
          {:ok, :created, Process.get(:our_home_url) <> url}

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

      ctxs =
        Memento.transaction!(fn ->
          post = Memento.Query.read(Post, url)

          # We want to e.g. notify posts that aren't mentioned anymore too
          all_old_ctxs =
            MapSet.union(
              Post.contexts_for(post.props),
              Markup.contexts_for(as_one(post.props["content"]))
            )

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

          ctxs_prop = Post.contexts_for(props)
          ctxs_cont = Markup.contexts_for(as_one(props["content"]))

          removed_ctxs = MapSet.difference(all_old_ctxs, MapSet.union(ctxs_prop, ctxs_cont))

          props =
            Map.update(
              props,
              "x-sr2-ctxs-removed",
              MapSet.to_list(removed_ctxs),
              &(MapSet.new(as_many(&1))
                |> MapSet.union(removed_ctxs)
                |> MapSet.difference(ctxs_prop)
                |> MapSet.difference(ctxs_cont)
                |> MapSet.to_list())
            )

          Memento.Query.write(%{
            post
            | props: props |> Map.delete("status") |> MediaUpload.replace_all(),
              updated: DateTime.utc_now(),
              status: Post.valid_status(props["status"])
          })

          ctxs_prop
        end)

      # the fetches also notify, and notifications are debounced,
      # so in the ideal case (fast fetches), the actions (generate etc) will be taken only once
      fetch_contexts(ctxs, url: url)
      Events.notify_urls_updated([url])

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
  defearlyret handle_source_query(url, _filter_properties, token) do
    ret_if not Bearer.is_allowed?(token), do: {:error, :insufficient_scope, :unauthorized}

    # TODO: filter properties
    # XXX: duplication of Serve/get_ logic
    url = read_url(url)
    # urls_local = Post.urls_local()
    posts = %Post.DbAsMap{}

    ret_if posts[url].deleted, do: {:error, :insufficient_scope, :deleted}

    {:ok, Post.to_full_map(posts[url])}
  end

  @impl true
  def handle_syndicate_to_query(token) do
    if Bearer.is_allowed?(token) do
      {:ok, %{}}
    else
      {:error, :insufficient_scope, :unauthorized}
    end
  end

  def s3_bucket, do: System.get_env("SR2_S3_BUCKET")
  def s3_region, do: System.get_env("SR2_S3_REGION")

  def upload_file(file) do
    # key slugified esp. to avoid https://stackoverflow.com/q/44779042
    key = Slugger.slugify(Path.rootname(file.filename)) <> Path.extname(file.filename)
    url = "https://#{s3_bucket()}.s3.dualstack.#{s3_region()}.amazonaws.com/#{key}"
    token = MediaUpload.create(url)

    ExAws.S3.Upload.stream_file(file.path)
    |> ExAws.S3.upload(s3_bucket(), key,
      content_disposition: "inline",
      content_type: file.content_type,
      acl: :public_read,
      meta: ["imgroll-cb": Process.get(:our_home_url) <> "/__imgroll_callback__/" <> token]
    )
    |> ExAws.request!(region: s3_region())

    url
  end

  @impl true
  def handle_media(file, token) do
    if Bearer.is_allowed?(token, :media) do
      {:ok, upload_file(file)}
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

    if is_binary(custom) && String.length(custom) > 5 do
      custom
    else
      name = as_one(properties["name"])

      if is_binary(name) && String.length(name) > 5 do
        Slugger.slugify(name)
      else
        Timex.format!(DateTime.utc_now(), "{ISOdate}-{h24}-{m}-{s}")
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
