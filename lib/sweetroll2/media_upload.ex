defmodule Sweetroll2.MediaUpload do
  @moduledoc """
  A Mnesia table for storing media processing tokens.
  """

  require Logger

  alias Sweetroll2.{Post, Convert, Events}

  use Memento.Table,
    attributes: [:token, :date, :url, :object]

  def create(url) do
    token = "U-" <> Nanoid.Secure.generate()

    Memento.transaction!(fn ->
      now = DateTime.utc_now()

      Memento.Query.write(%__MODULE__{
        token: token,
        date: now,
        url: url,
        object: nil
      })
    end)

    token
  end

  def fill(token, obj) do
    Memento.transaction!(fn ->
      upload = Memento.Query.read(__MODULE__, token)

      Logger.info("filling media upload for '#{upload.url}'",
        event: %{filling_upload: %{token: token, upload: upload.url, object: obj}}
      )

      Memento.Query.write(%{upload | object: obj})

      for post <- Memento.Query.select(Post, {:"/=", :status, :fetched}) do
        if Enum.any?(post.props, fn {k, v} -> is_list(v) and upload.url in v end) do
          Logger.info("inserting media object for '#{upload.url}' into '#{post.url}'",
            event: %{inserting_upload: %{upload: upload.url, post: post.url}}
          )

          props =
            Enum.map(post.props, fn {k, v} ->
              {k, Convert.as_many(v) |> Enum.map(&if(&1 == upload.url, do: obj, else: &1))}
            end)
            |> Enum.into(%{})

          Memento.Query.write(%{post | props: props})
          post.url
        else
          nil
        end
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Events.notify_urls_updated()
  end
end
