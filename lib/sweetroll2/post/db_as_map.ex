defmodule Sweetroll2.Post.DbAsMap do
  @behaviour Access
  @moduledoc """
  Access implementation for the post database.

  The idea is that you can either use a Map
  (for a preloaded local snapshot of the DB or for test data)
  or this blank struct (for live DB access).
  """

  defstruct []

  @impl Access
  def fetch(%__MODULE__{}, key) do
    case :mnesia.dirty_read(Sweetroll2.Post, key) do
      # Memento.Query.Data.load is too dynamic -> too slow
      [{Sweetroll2.Post, url, deleted, published, updated, acl, type, props, children} | _] ->
        {:ok,
         %Sweetroll2.Post{
           url: url,
           deleted: deleted,
           published: published,
           updated: updated,
           acl: acl,
           type: type,
           props: props,
           children: children
         }}

      _ ->
        :error
    end
  end
end
