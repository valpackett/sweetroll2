defmodule Sweetroll2.Auth.Serve do
  require Logger
  import ExEarlyRet
  alias Sweetroll2.{Auth.AccessToken, Auth.Session, Auth.TempCode, Render}
  use Plug.Router

  plug :match
  plug :dispatch

  get "/login" do
    {:safe, body} =
      Render.page_login(
        err: nil,
        redir: conn.query_params["redirect_uri"] || "/",
        csp_nonce: :crypto.strong_rand_bytes(24) |> Base.url_encode64()
      )

    resp(conn, :ok, body)
  end

  post "/login" do
    # TODO: use hashcash to prevent spam logins from starting slow argon2 calc
    # TODO: 2FA
    if conn.body_params["pwd"] &&
         Argon2.verify_pass(conn.body_params["pwd"], System.get_env("SR2_PASSWORD_HASH")) do
      token = Session.create(user_agent: conn.req_headers[:"user-agent"])

      conn
      |> Session.set_cookie(token)
      |> put_resp_header("Location", conn.body_params["redirect_uri"] || "/")
      |> resp(:found, "")
    else
      {:safe, body} =
        Render.page_login(
          err: "No correct password provided",
          redir: nil,
          csp_nonce: :crypto.strong_rand_bytes(24) |> Base.url_encode64()
        )

      resp(conn, :ok, body)
    end
  end

  post "/logout" do
    Session.revoke(Session.current_token(conn))

    conn
    |> Session.drop_cookie()
    |> put_resp_header("Location", (conn.body_params && conn.body_params["redirect_uri"]) || "/")
    |> resp(:found, "")
  end

  # https://indieauth.spec.indieweb.org/#authorization-endpoint-0

  get "/authorize" do
    if is_nil(Session.current_token(conn)) do
      conn
      |> put_resp_header(
        "Location",
        "/__auth__/login?#{
          URI.encode_query(%{"redirect_uri" => "/__auth__/authorize?" <> conn.query_string})
        }"
      )
      |> resp(:found, "")
    else
      Logger.info(
        "authorize request",
        event: %{
          authorize_request: %{params: conn.query_params, our_home: Process.get(:our_home_url)}
        }
      )

      {status, err} =
        cond do
          me_param(conn) != Process.get(:our_home_url) ->
            {:bad_request, "Wrong host"}

          is_nil(conn.query_params["redirect_uri"]) or
              !String.starts_with?(conn.query_params["redirect_uri"], "http") ->
            {:bad_request, "No valid redirect URI"}

          is_nil(conn.query_params["client_id"]) ->
            {:bad_request, "No client ID"}

          conn.query_params["response_type"] != "id" and
              conn.query_params["response_type"] != "code" ->
            {:bad_request, "Unknown response type"}

          true ->
            {:ok, nil}
        end

      # TODO fetch client_id
      {:safe, body} =
        Render.page_authorize(
          err: err,
          query: conn.query_params,
          scopes: split_scopes(conn.query_params["scope"]),
          csp_nonce: :crypto.strong_rand_bytes(24) |> Base.url_encode64()
        )

      resp(conn, status, body)
    end
  end

  post "/allow" do
    if is_nil(Session.current_token(conn)) do
      resp(conn, :unauthorized, "WTF")
    else
      code =
        TempCode.create(
          session: Session.current_token(conn),
          client_id: conn.body_params["client_id"],
          redirect_uri: conn.body_params["redirect_uri"],
          scopes: split_scopes(conn.body_params["scope"])
        )

      orig_uri = URI.parse(conn.body_params["redirect_uri"])

      new_query =
        URI.decode_query(orig_uri.query || "")
        |> Map.put("code", code)
        |> Map.put("state", conn.body_params["state"])

      new_uri = %{orig_uri | query: URI.encode_query(new_query)}

      conn
      |> put_resp_header("Location", URI.to_string(new_uri))
      |> resp(:found, "")
    end
  end

  # https://indieauth.spec.indieweb.org/#authorization-code-verification

  post "/authorize" do
    {status, body} =
      earlyret do
        redir = conn.body_params["redirect_uri"]

        ret_if is_nil(redir) or !String.starts_with?(redir, "http"),
          do: {:bad_request, "No valid redirect URI"}

        clid = conn.body_params["client_id"]

        ret_if is_nil(clid), do: {:bad_request, "No client ID"}

        ret_if is_nil(conn.body_params["code"]), do: {:bad_request, "No code"}

        tempcode = TempCode.get_if_valid(conn.body_params["code"])

        ret_if is_nil(tempcode), do: {:bad_request, "Code is not valid"}

        ret_if tempcode.redirect_uri != redir,
          do:
            {:bad_request,
             "redirect_uri does not match: '#{redir}' vs '#{tempcode.redirect_uri}'"}

        ret_if tempcode.client_id != clid,
          do: {:bad_request, "client_id does not match: '#{clid}' vs '#{tempcode.client_id}'"}

        TempCode.use(tempcode.code)

        Jason.encode(%{
          me: Process.get(:our_home_url)
        })
      end

    if status == :bad_request,
      do: Logger.error(body, event: %{authorization_failed: %{reason: body}})

    conn
    |> put_resp_content_type(if status == :ok, do: "application/json", else: "text/plain")
    |> resp(status, body)
  end

  # https://indieauth.spec.indieweb.org/#token-endpoint-0

  post "/token" do
    {status, body} =
      earlyret do
        ret_if conn.body_params["grant_type"] != "authorization_code",
          do: {:bad_request, "No/unknown grant type"}

        ret_if me_param(conn) != Process.get(:our_home_url), do: {:bad_request, "Wrong host"}

        redir = conn.body_params["redirect_uri"]

        ret_if is_nil(redir) or !String.starts_with?(redir, "http"),
          do: {:bad_request, "No valid redirect URI"}

        clid = conn.body_params["client_id"]

        ret_if is_nil(clid), do: {:bad_request, "No client ID"}

        ret_if is_nil(conn.body_params["code"]), do: {:bad_request, "No code"}

        tempcode = TempCode.get_if_valid(conn.body_params["code"])

        ret_if is_nil(tempcode), do: {:bad_request, "Code is not valid"}

        ret_if tempcode.redirect_uri != redir,
          do:
            {:bad_request,
             "redirect_uri does not match: '#{redir}' vs '#{tempcode.redirect_uri}'"}

        ret_if tempcode.client_id != clid,
          do: {:bad_request, "client_id does not match: '#{clid}' vs '#{tempcode.client_id}'"}

        TempCode.use(tempcode.code)
        token = AccessToken.create(tempcode)

        Jason.encode(%{
          token_type: "Bearer",
          access_token: token,
          me: Process.get(:our_home_url),
          scope: Enum.join(tempcode.scopes, " ")
        })
      end

    if status == :bad_request,
      do: Logger.error(body, event: %{token_grant_failed: %{reason: body}})

    conn
    |> put_resp_content_type(if status == :ok, do: "application/json", else: "text/plain")
    |> resp(status, body)
  end

  defp split_scopes(scope) do
    (scope || "create")
    |> String.slice(0..420)
    |> String.replace("post", "create")
    |> String.split()
  end

  defp me_param(conn) do
    (conn.query_params["me"] || conn.body_params["me"] || "")
    |> String.replace_trailing("/", "")
  end
end
