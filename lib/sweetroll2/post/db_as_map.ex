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
      [x | _] -> {:ok, Memento.Query.Data.load(x)}
      _ -> :error
    end
  end
end
