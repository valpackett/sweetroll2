defmodule Sweetroll2.Application do
  # https://hexdocs.pm/elixir/Application.html
  # https://hexdocs.pm/elixir/Supervisor.html
  @moduledoc false

  use Application

  def start(_type, _args) do
    server_opts =
      case {System.get_env("SERVER_SOCKET"), System.get_env("SERVER_PORT")} do
        {nil, nil} -> [port: 6969]
        {nil, port} -> [port: String.to_integer(port)]
        {sock, _} -> [ip: {:local, sock}, port: 0]
      end

    children = [
      {Sweetroll2.Repo, []},
      Sweetroll2.Cache,
      Sweetroll2.Notify,
      {Sweetroll2.Queue, repo: Sweetroll2.Repo, max_demand: 69},
      Plug.Cowboy.child_spec(scheme: :http, plug: Sweetroll2.Serve, options: server_opts)
    ]

    opts = [strategy: :one_for_one, name: Sweetroll2.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
