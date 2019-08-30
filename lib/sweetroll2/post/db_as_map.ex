defmodule Sweetroll2.Post.DbAsMap do
  @behaviour Access
  @moduledoc """
  Access implementation for the post database.

  The idea is that you can either use a Map
  (for a preloaded local snapshot of the DB or for test data)
  or this blank struct (for live DB access).

  Process dictionary caching is used because Mnesia access is
  not actually as fast as process-local data.
  So this is designed for web requests, not long-running processes.
  """

  defstruct []

  @impl Access
  def fetch(%__MODULE__{}, key) do
    if result = Process.get(key) do
      {:ok, result}
    else
      case :mnesia.dirty_read(Sweetroll2.Post, key) do
        # Memento.Query.Data.load is too dynamic -> too slow
        [{Sweetroll2.Post, url, deleted, published, updated, status, type, props, children} | _] ->
          post = %Sweetroll2.Post{
            url: url,
            deleted: deleted,
            published: published,
            updated: updated,
            status: status,
            type: type,
            props: props,
            children: children
          }

          Process.put(key, post)
          {:ok, post}

        _ ->
          :error
      end
    end
  end
end
