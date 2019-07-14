defmodule Sweetroll2 do
  @moduledoc false

  def our_host do
    URI.parse(System.get_env("SR2_OUR_HOST") || "http://localhost")
  end
end
