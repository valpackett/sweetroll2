defmodule Mix.Tasks.Sweetroll2.Export do
  use Mix.Task

  @shortdoc "Export entries from the Mnesia DB as JSON Lines to stdout"

  @impl Mix.Task
  @doc false
  def run(_raw_args) do
    :ok = Memento.start()
    # XXX: why do we need to wait for mnesia to pick up the db??
    Process.sleep(500)

    posts = Memento.transaction!(fn -> Memento.Query.all(Sweetroll2.Post) end)

    for post <- posts do
      post |> Sweetroll2.Post.to_map() |> Jason.encode!() |> IO.puts()
    end
  end
end
