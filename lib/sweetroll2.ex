defmodule Sweetroll2 do
  @moduledoc false
  @default_home "http://localhost:6969"

  def canonical_home_url, do: System.get_env("SR2_CANONICAL_HOME_URL") || @default_home
end
