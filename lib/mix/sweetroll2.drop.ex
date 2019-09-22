defmodule Mix.Tasks.Sweetroll2.Drop do
  use Mix.Task

  @shortdoc "Deletes the Mnesia DB on disk for Sweetroll2"

  @impl Mix.Task
  @doc false
  def run(_) do
    :ok = Memento.start()

    :ok =
      :mnesia.wait_for_tables(
        [
          Sweetroll2.Post,
          Sweetroll2.Auth.Session,
          Sweetroll2.Auth.TempCode,
          Sweetroll2.Auth.AccessToken,
          Que.Persistence.Mnesia.DB.Jobs
        ],
        1000
      )

    Sweetroll2.Application.drop!()
  end
end
