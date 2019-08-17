defmodule Sweetroll2.Serve do
  @parsers [:urlencoded, {:multipart, length: 20_000_000}, :json]

  alias Sweetroll2.{Auth, Post, Render, Job}

  use Plug.Router

  if Mix.env() == :dev do
    use Plug.Debugger, otp_app: :sweetroll2
  end

  use Plug.ErrorHandler

  plug :fprofile
  plug Plug.RequestId
  plug Timber.Plug.HTTPContext
  plug Timber.Plug.Event
  plug Plug.SSL, rewrite_on: [:x_forwarded_proto]
  plug Plug.Head
  plug :add_host_to_process
  plug :add_links

  plug Plug.Static,
    at: "/__as__",
    from: :sweetroll2,
    cache_control_for_vsn_requests: "public, max-age=31536000, immutable",
    gzip: true,
    brotli: true

  plug Plug.MethodOverride
  plug :match
  plug Plug.Parsers, parsers: @parsers, json_decoder: Jason
  plug Auth.Session
  plug :fetch_session
  plug :skip_csrf_anon
  plug Plug.CSRFProtection
  plug :dispatch

  forward "/__auth__", to: Auth.Serve

  forward "/__micropub__",
    to: PlugMicropub,
    init_opts: [
      handler: Sweetroll2.Micropub,
      json_encoder: Jason
    ]

  post "/__webmention__" do
    sourceu = URI.parse(conn.body_params["source"])
    targetu = URI.parse(conn.body_params["target"])
    posts = %Post.DbAsMap{}

    cond do
      is_nil(conn.body_params["source"]) ->
        send_resp(conn, :bad_request, "No source parameter")

      is_nil(conn.body_params["target"]) ->
        send_resp(conn, :bad_request, "No target parameter")

      sourceu.scheme != "https" and sourceu.scheme != "http" ->
        send_resp(conn, :bad_request, "Non-HTTP(S) source parameter")

      String.starts_with?(conn.body_params["source"], Process.get(:our_home_url)) ->
        send_resp(
          conn,
          :bad_request,
          "Source parameter on our host (must not be on '#{Process.get(:our_home_url)}')"
        )

      !String.starts_with?(conn.body_params["target"], Process.get(:our_home_url)) ->
        send_resp(
          conn,
          :bad_request,
          "Target parameter not on our host (must be on '#{Process.get(:our_home_url)}')"
        )

      is_nil(posts[targetu.path]) || posts[targetu.path].deleted ->
        send_resp(conn, :bad_request, "Target post does not exist")

      true ->
        Que.add(Job.Fetch,
          url: conn.body_params["source"],
          check_mention: conn.body_params["target"],
          save_mention: targetu.path,
          notify_update: [targetu.path]
        )

        send_resp(conn, :accepted, "Accepted for processing")
    end
  end

  get "/__firehose__" do
    SSE.stream(conn, {[:url_updated], %SSE.Chunk{data: ""}})
  end

  get _ do
    conn =
      conn
      |> put_resp_content_type("text/html")
      |> put_resp_header(
        "Feature-Policy",
        "unsized-media 'none'; sync-xhr 'none'; document-write 'none'"
      )
      |> put_resp_header("Referrer-Policy", "no-referrer-when-downgrade")
      |> put_resp_header("X-XSS-Protection", "1; mode=block")

    url = conn.request_path
    posts = %Post.DbAsMap{}
    urls_local = Post.urls_local()
    urls_dyn = Post.DynamicUrls.dynamic_urls()
    {durl, params} = if Map.has_key?(urls_dyn, url), do: urls_dyn[url], else: {url, %{}}

    cond do
      !(durl in urls_local) ->
        send_resp(conn, 404, "Page not found")

      !("*" in (posts[durl].acl || ["*"])) ->
        send_resp(conn, 401, "Unauthorized")

      posts[durl].deleted ->
        send_resp(conn, 410, "Gone")

      true ->
        # NOTE: chunking without special considerations would break CSRF tokens
        {:safe, data} =
          Render.render_post(
            post: posts[durl],
            params: params,
            posts: posts,
            local_urls: urls_local,
            logged_in: !is_nil(Auth.Session.current_token(conn))
          )

        send_resp(conn, :ok, data)
    end
  end

  def handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack}) do
    send_resp(conn, 500, "Something went wrong")
  end

  @link_header ExHttpLink.generate([
                 {"/__webmention__", {"rel", "webmention"}},
                 {Job.NotifyWebsub.hub(), {"rel", "hub"}},
                 {"/__micropub__", {"rel", "micropub"}},
                 {"/__auth__/authorize", {"rel", "authorization_endpoint"}},
                 {"/__auth__/token", {"rel", "token_endpoint"}}
               ])

  defp add_links(conn, _opts) do
    put_resp_header(
      conn,
      "link",
      @link_header <>
        ", " <>
        ExHttpLink.generate([
          {"#{Process.get(:our_home_url)}#{conn.request_path}", {"rel", "self"}}
        ])
    )
  end

  defp skip_csrf_anon(conn, _opts) do
    # we don't have anonymous sessions, so we can't exactly store the CSRF token in a session
    # when logged out (this enables the login form to work)
    if is_nil(Auth.Session.current_token(conn)) do
      put_private(conn, :plug_skip_csrf_protection, true)
    else
      conn
    end
  end

  @doc """
  Puts the request host with scheme and port but without path (not even /) into the process dictionary.

  NOTE: reverse proxies must be configured to preserve Host!
  """
  defp add_host_to_process(conn, _opts) do
    Process.put(
      :our_home_url,
      if(conn.port != 443 and conn.port != 80,
        do: "#{conn.scheme}://#{conn.host}:#{conn.port}",
        else: "#{conn.scheme}://#{conn.host}"
      )
    )

    conn
  end

  defp fprofile(conn, _opts) do
    conn = fetch_query_params(conn)

    if Mix.env() != :prod and Map.has_key?(conn.query_params, "fprof") do
      :fprof.trace(:start)

      register_before_send(conn, fn conn ->
        :fprof.trace(:stop)
        :fprof.profile()
        conn
      end)
    else
      conn
    end
  end
end
