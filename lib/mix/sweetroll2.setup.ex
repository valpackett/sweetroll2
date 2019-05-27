defmodule Mix.Tasks.Sweetroll2.Setup do
  use Mix.Task

  @shortdoc "Creates a Mnesia DB on disk for Sweetroll2"

  @impl Mix.Task
  @doc false
  def run(_) do
    Sweetroll2.Application.setup!()
  end
end
