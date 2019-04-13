defmodule Sweetroll2.Serve do
  @parsers [:urlencoded, {:multipart, length: 20_000_000}, :json]

  alias Sweetroll2.{Doc, Cache, Render}

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
    preload = %Cache{}
    urls_local = Cache.urls_local()

    cond do
      !(url in urls_local) ->
        send_resp(conn, 404, "Page not found")

      !("*" in preload[url].acl) ->
        send_resp(conn, 401, "Unauthorized")

      preload[url].deleted ->
        send_resp(conn, 410, "Gone")

      true ->
        conn = send_chunked(conn, 200)
        {:safe, data} = Render.render_doc(doc: preload[url], preload: preload, allu: urls_local)
        chunk(conn, data)
        conn
    end
  end

  def handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack}) do
    send_resp(conn, 500, "Something went wrong")
  end
end
