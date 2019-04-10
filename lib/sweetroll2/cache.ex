defmodule Sweetroll2.Cache do
  alias Sweetroll2.Repo
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl Supervisor
  def init(:ok) do
    children = [
      {ConCache,
       [
         name: :docs,
         ttl_check_interval: :timer.seconds(5),
         global_ttl: :timer.seconds(60)
       ]},
      Sweetroll2.Cache.Uncacher
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def urls_local do
    ConCache.get_or_store(:docs, "___urls_local___", &Repo.urls_local/0)
  end

  defstruct []
  @behaviour Access

  @impl Access
  def fetch(%__MODULE__{}, key) do
    ConCache.get_or_store(:docs, key, fn ->
      case Repo.doc_by_url(key) do
        nil -> :error
        x -> {:ok, x}
      end
    end)
  end
end

defmodule Sweetroll2.Cache.Uncacher do
  require Logger
  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, :ok, opts ++ [name: __MODULE__])

  @impl GenServer
  def init(:ok) do
    EventBus.subscribe({__MODULE__, ["doc_changed"]})
    {:ok, nil}
  end

  def process(event_shadow) do
    GenServer.cast(__MODULE__, event_shadow)
    :ok
  end

  @impl GenServer
  def handle_cast(event_shadow, state) do
    event = EventBus.fetch_event(event_shadow)
    Logger.info("uncaching url=#{event.data}")
    ConCache.delete(:docs, event.data)
    EventBus.mark_as_completed({__MODULE__, event_shadow})
    {:noreply, state}
  end
end
