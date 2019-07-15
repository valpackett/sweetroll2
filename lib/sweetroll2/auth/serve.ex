defmodule Sweetroll2.Auth.Serve do
  alias Sweetroll2.{Render, Auth.Session}
  use Plug.Router

  plug :match
  plug :dispatch

  get "/login" do
    {:safe, body} = Render.page_login(err: nil)
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
      |> put_resp_header("Location", conn.body_params["redirect_url"] || "/")
      |> resp(:found, "")
    else
      {:safe, body} = Render.page_login(err: "No correct password provided")
      resp(conn, :ok, body)
    end
  end

  post "/logout" do
    Session.revoke(Session.current_token(conn))

    conn
    |> Session.drop_cookie()
    |> put_resp_header("Location", conn.body_params["redirect_url"] || "/")
    |> resp(:found, "")
  end
end
