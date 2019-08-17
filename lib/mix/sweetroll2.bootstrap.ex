defmodule Mix.Tasks.Sweetroll2.Bootstrap do
  use Mix.Task

  @shortdoc "Adds default entries (pages) to the database"

  @impl Mix.Task
  @doc false
  def run(_) do
    Sweetroll2.Application.bootstrap!()
  end
end
