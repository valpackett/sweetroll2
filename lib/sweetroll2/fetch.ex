defmodule Sweetroll2.Fetch do
  alias Sweetroll2.{Post, Convert}

  def href_matches?({_, attrs, _}, url) do
    attrs
    |> Enum.filter(fn {k, _} -> k == "href" end)
    |> Enum.all?(fn {_, v} -> v == url end)
  end

  def fetch(url, check_mention: check_mention) do
    u = URI.parse(url)

    cond do
      u.scheme != "http" && u.scheme != "https" ->
        {:non_http_scheme, u.scheme}

      u.host == nil || u.host == "localhost" ->
        {:local_host, u.host}

      true ->
        # TODO handle 410 Gone
        resp = HTTPotion.get!(url)
        html = Floki.parse(resp.body)

        if check_mention == nil ||
             Enum.any?(Floki.find(html, "a"), &href_matches?(&1, check_mention)) do
          mf =
            Microformats2.parse(html, url)
            |> Convert.find_mf_with_url(url)
            |> Convert.simplify()

          {:ok, mf}
        else
          {:no_mention, check_mention}
        end
    end
  end
end
