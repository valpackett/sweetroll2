defmodule Sweetroll2 do
  @moduledoc false

  def our_host do
    URI.parse(System.get_env("OUR_HOST") || "https://ruunvald.lan")
  end
end
