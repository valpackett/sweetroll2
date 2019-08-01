defmodule Sweetroll2.Auth.Serve do
  require Logger
  alias Sweetroll2.{Render, Auth.Session, Auth.TempCode, Auth.AccessToken}
  use Plug.Router

  plug :match
  plug :dispatch

  get "/login" do
    {:safe, body} = Render.page_login(err: nil, redir: conn.query_params["redirect_uri"] || "/")
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
      {:safe, body} = Render.page_login(err: "No correct password provided", redir: nil)
      resp(conn, :ok, body)
    end
  end

  post "/logout" do
    Session.revoke(Session.current_token(conn))

    conn
    |> Session.drop_cookie()
    |> put_resp_header("Location", conn.body_params["redirect_uri"] || "/")
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
        "authorize request: #{inspect(conn.query_params)}, our home: #{Process.get(:our_home_url)}"
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
          scopes: split_scopes(conn.query_params["scope"])
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
      cond do
        is_nil(conn.body_params["redirect_uri"]) or
            !String.starts_with?(conn.body_params["redirect_uri"], "http") ->
          {:bad_request, "No valid redirect URI"}

        is_nil(conn.body_params["client_id"]) ->
          {:bad_request, "No client ID"}

        is_nil(conn.body_params["code"]) ->
          {:bad_request, "No code"}

        true ->
          tempcode = TempCode.get_if_valid(conn.body_params["code"])

          cond do
            is_nil(tempcode) ->
              {:bad_request, "Code is not valid"}

            tempcode.redirect_uri != conn.body_params["redirect_uri"] ->
              {:bad_request,
               "redirect_uri does not match: '#{conn.body_params["redirect_uri"]}' vs '#{
                 tempcode.redirect_uri
               }'"}

            tempcode.client_id != conn.body_params["client_id"] ->
              {:bad_request,
               "client_id does not match: '#{conn.body_params["client_id"]}' vs '#{
                 tempcode.client_id
               }'"}

            true ->
              TempCode.use(tempcode.code)

              Jason.encode(%{
                me: Process.get(:our_home_url)
              })
          end
      end

    if status == :bad_request, do: Logger.error(body)

    conn
    |> put_resp_content_type(if status == :ok, do: "application/json", else: "text/plain")
    |> resp(status, body)
  end

  # https://indieauth.spec.indieweb.org/#token-endpoint-0

  post "/token" do
    {status, body} =
      cond do
        conn.body_params["grant_type"] != "authorization_code" ->
          {:bad_request, "No/unknown grant type"}

        me_param(conn) != Process.get(:our_home_url) ->
          {:bad_request, "Wrong host"}

        is_nil(conn.body_params["redirect_uri"]) or
            !String.starts_with?(conn.body_params["redirect_uri"], "http") ->
          {:bad_request, "No valid redirect URI"}

        is_nil(conn.body_params["client_id"]) ->
          {:bad_request, "No client ID"}

        is_nil(conn.body_params["code"]) ->
          {:bad_request, "No code"}

        true ->
          tempcode = TempCode.get_if_valid(conn.body_params["code"])

          cond do
            is_nil(tempcode) ->
              {:bad_request, "Code is not valid"}

            tempcode.redirect_uri != conn.body_params["redirect_uri"] ->
              {:bad_request,
               "redirect_uri does not match: '#{conn.body_params["redirect_uri"]}' vs '#{
                 tempcode.redirect_uri
               }'"}

            tempcode.client_id != conn.body_params["client_id"] ->
              {:bad_request,
               "client_id does not match: '#{conn.body_params["client_id"]}' vs '#{
                 tempcode.client_id
               }'"}

            true ->
              TempCode.use(tempcode.code)
              token = AccessToken.create(tempcode)

              Jason.encode(%{
                token_type: "Bearer",
                access_token: token,
                me: Process.get(:our_home_url),
                scope: Enum.join(tempcode.scopes, " ")
              })
          end
      end

    if status == :bad_request, do: Logger.error(body)

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
