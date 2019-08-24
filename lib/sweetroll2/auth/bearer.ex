defmodule Sweetroll2.Auth.Bearer do
  @moduledoc """
  Common entry point for checking tokens, which can be both
  cookie sessions and OAuth access tokens.
  """

  require Logger
  alias Sweetroll2.Auth.{Session, AccessToken}

  def is_allowed?(token, scope \\ nil)

  def is_allowed?("C-" <> _ = token, _) do
    # Cookie sessions can do anything
    !is_nil(Session.get_if_valid(token))
  end

  def is_allowed?("T-" <> _ = token, scope) do
    accesstoken = AccessToken.get_if_valid(token)

    if accesstoken do
      result = !is_nil(accesstoken) and (is_nil(scope) or to_string(scope) in accesstoken.scopes)

      Logger.info("checking scope #{to_string(scope)}",
        event: %{
          access_token_scope_check: %{scope: scope, allowed: accesstoken.scopes, result: result}
        }
      )

      result
    else
      Logger.info("no access token", event: %{access_token_not_found: %{}})
      false
    end
  end
end
