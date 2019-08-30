defmodule Mix.Tasks.Sweetroll2.Drop do
  use Mix.Task

  @shortdoc "Deletes the Mnesia DB on disk for Sweetroll2"

  @impl Mix.Task
  @doc false
  def run(_) do
    Memento.start()
    Process.sleep(500)
    Sweetroll2.Application.drop!()
  end
end
