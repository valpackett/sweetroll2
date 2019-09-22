defmodule Mix.Tasks.Sweetroll2.Bootstrap do
  use Mix.Task

  @shortdoc "Adds default entries (pages) to the database"

  @impl Mix.Task
  @doc false
  def run(_) do
    :ok = Memento.start()
    :ok = :mnesia.wait_for_tables([Sweetroll2.Post], 1000)

    Sweetroll2.Application.bootstrap!()
  end
end
