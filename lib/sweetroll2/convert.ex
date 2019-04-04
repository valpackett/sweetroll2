defmodule Sweetroll2.Convert do
  def as_one(x) when is_list(x), do: List.first(x)
  def as_one(x), do: x

  def as_many(nil), do: []
  def as_many(xs) when is_list(xs), do: xs
  def as_many(x), do: [x]

  def simplify(s = %{__struct__: _}), do: s

  def simplify(map) when is_map(map) do
    type = map[:type] || map["type"]
    props = map[:properties] || map["properties"]

    if type && props && is_map(props) do
      props
      |> Enum.map(&simplify/1)
      |> Enum.into(%{})
      |> Map.merge(%{
        "type" => String.replace_prefix(List.first(type || []), "h-", "")
      })
    else
      map
      |> Enum.map(&simplify/1)
      |> Enum.into(%{})
    end
  end

  def simplify({k, [v]}), do: {k, simplify(v)}
  def simplify({k, vs}) when is_list(vs), do: {k, Enum.map(vs, &simplify/1)}
  def simplify({k, v}), do: {k, simplify(v)}
  def simplify(x), do: x

  def find_mf_with_url(%{items: items}, url) do
    Enum.find(items, fn item ->
      url in (item["properties"]["url"] || [])
    end) || List.first(items)
  end
end
