defmodule Sweetroll2.Serve do
  @parsers [:urlencoded, {:multipart, length: 20_000_000}, :json]

  alias Sweetroll2.{Post, Render}

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
    posts = %Post.DbAsMap{}
    urls_local = Post.urls_local()
    urls_dyn = Post.DynamicUrls.dynamic_urls(posts, urls_local)
    {durl, params} = if Map.has_key?(urls_dyn, url), do: urls_dyn[url], else: {url, %{}}

    cond do
      !(durl in urls_local) ->
        send_resp(conn, 404, "Page not found")

      !("*" in posts[durl].acl) ->
        send_resp(conn, 401, "Unauthorized")

      posts[durl].deleted ->
        send_resp(conn, 410, "Gone")

      true ->
        conn = send_chunked(conn, 200)

        {:safe, data} =
          Render.render_doc(
            doc: posts[durl],
            params: params,
            posts: posts,
            local_urls: urls_local
          )

        chunk(conn, data)
        conn
    end
  end

  def handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack}) do
    send_resp(conn, 500, "Something went wrong")
  end
end
