defmodule Sweetroll2.Queue do
  use EctoJob.JobQueue, table_name: "jobs"

  def perform(multi = %Ecto.Multi{}, job = %{"type" => "fetch"}),
    do: Sweetroll2.Fetch.perform(multi, job)

  def perform(multi = %Ecto.Multi{}, job = %{"type" => "generate"}),
    do: Sweetroll2.Generate.perform(multi, job)
end
