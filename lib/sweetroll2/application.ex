defmodule Sweetroll2.Application do
  # https://hexdocs.pm/elixir/Application.html
  # https://hexdocs.pm/elixir/Supervisor.html
  @moduledoc false

  use Application

  def start(_type, _args) do
    server_opts =
      case {System.get_env("SR2_SERVER_SOCKET"), System.get_env("SR2_SERVER_PORT")} do
        {nil, nil} -> [port: 6969]
        {nil, port} -> [port: String.to_integer(port)]
        {sock, _} -> [ip: {:local, sock}, port: 0]
      end

    children = [
      Plug.Cowboy.child_spec(scheme: :http, plug: Sweetroll2.Serve, options: server_opts),
      Sweetroll2.Post.DynamicUrls.Cache,
      Sweetroll2.Events
    ]

    opts = [strategy: :one_for_one, name: Sweetroll2.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def setup!(nodes \\ [node()]) do
    if path = Application.get_env(:mnesia, :dir) do
      :ok = File.mkdir_p!(path)
    end

    Memento.stop()
    Memento.Schema.create(nodes)
    Memento.start()
    Memento.Table.create!(Sweetroll2.Post, disc_copies: nodes)
    Memento.Table.create!(Sweetroll2.Auth.Session, disc_copies: nodes)
    Memento.Table.create!(Sweetroll2.Auth.TempCode, disc_copies: nodes)
    Memento.Table.create!(Sweetroll2.Auth.AccessToken, disc_copies: nodes)
  end
end
