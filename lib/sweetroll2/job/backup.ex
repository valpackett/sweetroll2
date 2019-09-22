defmodule Sweetroll2.Job.Backup do
  @hook_path "priv/hooks/backup"

  use Que.Worker

  def perform(path: path) do
    File.mkdir_p!(Path.dirname(path))
    :mnesia.backup(String.to_charlist(path))

    if File.exists?(@hook_path) do
      System.cmd("sh", [@hook_path, path])
    end
  end

  def enqueue() do
    Que.add(__MODULE__, path: "priv/backup/sr2-#{Mix.env()}.bak")
  end
end
