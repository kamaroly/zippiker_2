defmodule Zippiker.Catalog.Product.Preparations.Search do
  @moduledoc "Free-text search on name and SKU, optionally only active or stock-tracked products."
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    query
    |> search(Ash.Query.get_argument(query, :query))
    |> active(Ash.Query.get_argument(query, :active_only?))
    |> tracked(Ash.Query.get_argument(query, :tracked_only?))
  end

  defp search(query, term) when is_binary(term) and term != "" do
    pattern = "%" <> String.replace(String.trim(term), ~r/[%_\\]/, "\\\\\\0") <> "%"
    Ash.Query.filter(query, ilike(name, ^pattern) or ilike(sku, ^pattern))
  end

  defp search(query, _term), do: query

  defp active(query, true), do: Ash.Query.filter(query, active? == true)
  defp active(query, _), do: query

  defp tracked(query, true), do: Ash.Query.filter(query, track_inventory? == true)
  defp tracked(query, _), do: query
end
