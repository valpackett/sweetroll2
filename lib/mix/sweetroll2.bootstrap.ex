defmodule Mix.Tasks.Sweetroll2.Bootstrap do
  use Mix.Task

  @shortdoc "Adds default entries (pages) to the database"

  @impl Mix.Task
  @doc false
  def run(_) do
    :ok = Memento.start()
    # XXX: why do we need to wait for mnesia to pick up the db??
    Process.sleep(500)

    Sweetroll2.Application.bootstrap!()
  end
end
