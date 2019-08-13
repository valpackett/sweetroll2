defmodule Sweetroll2.Auth.TempCode do
  @moduledoc """
  A Mnesia table for storing IndieAuth (OAuth) authorization codes.
  """

  @expiration 600

  require Logger

  use Memento.Table,
    attributes: [:code, :used_session, :grant_date, :client_id, :redirect_uri, :scopes, :used]

  def create(session: session, client_id: client_id, redirect_uri: redirect_uri, scopes: scopes) do
    code = Nanoid.Secure.generate()

    Memento.transaction!(fn ->
      now = DateTime.utc_now()

      Memento.Query.write(%__MODULE__{
        code: code,
        used_session: session,
        grant_date: now,
        client_id: client_id,
        redirect_uri: redirect_uri,
        scopes: scopes,
        used: false
      })
    end)

    code
  end

  def use(code) do
    Memento.transaction!(fn ->
      tempcode = Memento.Query.read(__MODULE__, code)
      Memento.Query.write(%{tempcode | used: true})
    end)
  end

  def get_if_valid(code) do
    Memento.transaction!(fn ->
      tempcode = Memento.Query.read(__MODULE__, code)

      valid =
        !tempcode.used &&
          DateTime.compare(
            DateTime.utc_now(),
            DateTime.add(tempcode.grant_date, @expiration, :second)
          ) == :lt

      if valid do
        tempcode
      else
        nil
      end
    end)
  rescue
    err ->
      Logger.warn("tempcode not valid",
        event: %{temp_code_not_valid: %{code: code, error: inspect(err)}}
      )

      nil
  end
end
