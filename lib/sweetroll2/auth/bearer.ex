defmodule Sweetroll2.Auth.Bearer do
  @moduledoc """
  Common entry point for checking tokens, which can be both
  cookie sessions and OAuth access tokens.
  """

  alias Sweetroll2.Auth.{Session}

  def is_allowed?(token, scope \\ nil) do
    if String.starts_with?(token, "C-") do
      # Cookie sessions can do anything
      !is_nil(Session.get_if_valid(token))
    else
      # TODO access tokens
      false
    end
  end
end
