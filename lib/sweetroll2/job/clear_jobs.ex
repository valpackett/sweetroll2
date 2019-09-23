defmodule Sweetroll2.Job.ClearJobs do
  @moduledoc """
  Que job for removing old completed Que jobs. So meta.
  """

  require Logger
  alias Que.Persistence.Mnesia.DB.Jobs
  use Que.Worker

  def perform(keep: n) do
    Timber.add_context(que: %{job_id: Logger.metadata()[:job_id]})

    js = Jobs.completed_jobs()
    old_len = length(js)

    if old_len > n do
      Enum.slice(js, 0, old_len - n) |> Enum.each(&Jobs.delete_job/1)

      new_len = length(Jobs.completed_jobs())

      Logger.info("cleaned jobs",
        event: %{deleted_old_jobs: %{old_len: old_len, new_len: new_len}}
      )
    end
  end

  def enqueue(n \\ 69) do
    Que.add(__MODULE__, keep: n)
  end
end
