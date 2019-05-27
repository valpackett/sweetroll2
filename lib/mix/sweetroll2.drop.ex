defmodule Mix.Tasks.Sweetroll2.Drop do
  use Mix.Task

  @shortdoc "Deletes the Mnesia DB on disk for Sweetroll2"

  @impl Mix.Task
  @doc false
  def run(_) do
    Memento.start()
    Memento.Table.delete!(Sweetroll2.Doc)
  end
end
