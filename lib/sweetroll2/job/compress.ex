defmodule Sweetroll2.Job.Compress do
  require Logger
  use Que.Worker, concurrency: 2

  def perform(path: path) do
    System.cmd("zopfli", [path])
    System.cmd("brotli", ["--keep", "--best", "--force", path])
  end

  @asset_dir "priv/static"

  def enqueue_assets() do
    {:ok, files} = File.ls(@asset_dir)

    for file <- files do
      path = Path.join(@asset_dir, file)

      if !File.dir?(path) and !String.ends_with?(path, ".br") and !String.ends_with?(path, ".gz") do
        Que.add(Sweetroll2.Job.Compress, path: path)
      end

      if (String.ends_with?(path, ".br") or String.ends_with?(path, ".gz")) and
           !File.exists?(Path.rootname(path)) do
        File.rm(path)
      end
    end
  end

  defmodule AssetWatcher do
    require Logger
    use GenServer

    def start_link(args) do
      GenServer.start_link(__MODULE__, args)
    end

    def init(args) do
      {:ok, watcher_pid} = FileSystem.start_link(args)
      FileSystem.subscribe(watcher_pid)
      {:ok, %{watcher_pid: watcher_pid}}
    end

    def handle_info(
          {:file_event, watcher_pid, {path, events}},
          %{watcher_pid: watcher_pid} = state
        ) do
      if !String.ends_with?(path, ".br") and !String.ends_with?(path, ".gz") do
        for event <- events do
          case event do
            :created ->
              Logger.info("compressing new asset '#{path}'")
              Que.add(Sweetroll2.Job.Compress, path: path)

            :modified ->
              Logger.info("compressing modified asset '#{path}'")
              Que.add(Sweetroll2.Job.Compress, path: path)

            :deleted ->
              Logger.info("deleting compressed versions of asset '#{path}'")
              File.rm(path <> ".gz")
              File.rm(path <> ".br")

            _ ->
              true
          end
        end
      end

      {:noreply, state}
    end

    def handle_info({:file_event, watcher_pid, :stop}, %{watcher_pid: watcher_pid} = state) do
      Logger.error("FS watcher stopped")
      Process.sleep(10000)
      {:stop, :watcher_stopped, state}
    end
  end
end
