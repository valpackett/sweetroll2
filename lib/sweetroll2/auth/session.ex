defmodule Sweetroll2.Auth.Session do
  @moduledoc """
  A Mnesia table for storing site sessions (cookie based).
  And a Plug middleware for supporting sessions.

  We don't use Plug.Session because there's no need for backend flexibility
  and `put` being able to generate new sessions sounds weird.
  We only ever want to generate sessions in the login page.

  We do implement :plug_session stuff though, so e.g. Plug.CSRFProtection works.
  """
  @behaviour Plug

  @cookie_key "wheeeee"
  @expiration 31_557_600

  require Logger
  alias Plug.Conn

  use Memento.Table,
    attributes: [:token, :revoked, :data, :start_date, :start_user_agent, :last_access]

  def create(user_agent: user_agent) do
    token = "C-" <> Nanoid.Secure.generate()

    Memento.transaction!(fn ->
      now = DateTime.utc_now()

      Memento.Query.write(%__MODULE__{
        token: token,
        revoked: false,
        data: %{},
        start_date: now,
        start_user_agent: user_agent,
        last_access: now
      })
    end)

    token
  end

  def revoke(token) do
    Memento.transaction!(fn ->
      session = Memento.Query.read(__MODULE__, token)
      Memento.Query.write(%{session | revoked: true})
    end)
  end

  def get_if_valid(token) do
    Memento.transaction!(fn ->
      session = Memento.Query.read(__MODULE__, token)

      valid =
        !session.revoked &&
          DateTime.compare(
            DateTime.utc_now(),
            DateTime.add(session.start_date, @expiration, :second)
          ) == :lt

      if valid do
        session = %{session | last_access: DateTime.utc_now()}
        Memento.Query.write(session)
        session
      else
        nil
      end
    end)
  rescue
    err ->
      Logger.warn("session #{token} not valid: #{inspect(err)}")
      nil
  end

  # TODO: secure option when https, other options
  def set_cookie(conn, token) do
    Conn.put_resp_cookie(conn, @cookie_key, token, http_only: true, max_age: @expiration)
  end

  def drop_cookie(conn) do
    Conn.delete_resp_cookie(conn, @cookie_key, http_only: true, max_age: @expiration)
  end

  @doc "Gets the current session token after it was validated (don't forget to fetch_session!)"
  def current_token(conn) do
    conn.private[:sr2_session_token]
  end

  @impl true
  def init(opts), do: %{}

  @impl true
  def call(conn, _) do
    Conn.put_private(conn, :plug_session_fetch, fn conn ->
      conn = Conn.fetch_cookies(conn)

      if token = conn.cookies[@cookie_key] do
        if session = get_if_valid(token) do
          conn
          |> Conn.put_private(:sr2_session_token, token)
          |> Conn.put_private(:plug_session, session.data)
          |> Conn.register_before_send(fn conn ->
            if conn.private[:plug_session_info] == :write do
              Memento.transaction!(fn ->
                Memento.Query.write(%{session | data: conn.private[:plug_session]})
              end)
            end

            # we don't care about other actions
            conn
          end)
          |> Conn.put_req_header("authorization", "Bearer " <> token)

          # header for micropub middleware (will be reverified there, boo inefficiency)
        else
          drop_cookie(conn)
          |> Conn.put_private(:plug_session, %{})
        end
      else
        conn
        |> Conn.put_private(:plug_session, %{})
      end
      |> Conn.put_private(:plug_session_fetch, :done)
    end)
  end
end
