defmodule Sweetroll2.Auth.Bearer do
  @moduledoc """
  Common entry point for checking tokens, which can be both
  cookie sessions and OAuth access tokens.
  """

  require Logger
  alias Sweetroll2.Auth.{Session, AccessToken}

  def is_allowed?(token, scope \\ nil)

  def is_allowed?(token = "C-" <> _, _) do
    # Cookie sessions can do anything
    !is_nil(Session.get_if_valid(token))
  end

  def is_allowed?(token = "T-" <> _, scope) do
    accesstoken = AccessToken.get_if_valid(token)

    if !is_nil(accesstoken),
      do:
        Logger.info("auth: checking scope #{to_string(scope)} in #{inspect(accesstoken.scopes)}")

    !is_nil(accesstoken) and (is_nil(scope) or to_string(scope) in accesstoken.scopes)
  end
end
