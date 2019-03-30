defmodule Sweetroll2.Queue do
  alias Sweetroll2.Fetch
  use EctoJob.JobQueue, table_name: "jobs"

  def perform(multi = %Ecto.Multi{}, job = %{"type" => "fetch"}),
    do: Fetch.perform(multi, job)
end
