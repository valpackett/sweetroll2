defmodule Sweetroll2.Serve do
  @parsers [:urlencoded, {:multipart, length: 20_000_000}, :json]

  alias Sweetroll2.{Repo, Render}

  use Plug.Router

  if Mix.env() == :dev do
    use Plug.Debugger, otp_app: :sweetroll2
  end

  use Plug.ErrorHandler

  plug Plug.Logger
  plug Plug.RequestId
  plug Plug.Head

  plug Plug.Static,
    at: "/as",
    from: :sweetroll2,
    cache_control_for_vsn_requests: "public, max-age=31536000, immutable",
    gzip: true,
    brotli: true

  plug Plug.MethodOverride
  plug :match
  plug Plug.Parsers, parsers: @parsers, json_decoder: Jason
  plug :dispatch

  get _ do
    conn = put_resp_content_type(conn, "text/html; charset=utf-8")
    url = conn.request_path
    preload = Repo.docs_all()

    cond do
      !(url in Map.keys(preload)) ->
        send_resp(conn, 404, "Page not found")

      !("*" in preload[url].acl) ->
        send_resp(conn, 401, "Unauthorized")

      preload[url].deleted ->
        send_resp(conn, 410, "Gone")

      true ->
        {:safe, data} = Render.render_doc(doc: preload[url], preload: preload)
        send_resp(conn, 200, data)
    end
  end

  def handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack}) do
    send_resp(conn, 500, "Something went wrong")
  end
end
