defmodule Zippiker.Manufacturing.ProductionOrder.Preparations.Search do
  @moduledoc "Filters production orders by number/product text, status (`:open` = not closed) and product."
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    Enum.reduce([:query, :status, :product_id], query, fn argument, query ->
      filter(query, argument, Ash.Query.get_argument(query, argument))
    end)
  end

  defp filter(query, _argument, value) when value in [nil, ""], do: query

  defp filter(query, :query, term) do
    pattern = "%" <> String.replace(String.trim(term), ~r/[%_\\]/, "\\\\\\0") <> "%"
    Ash.Query.filter(query, ilike(number, ^pattern) or ilike(product.name, ^pattern))
  end

  defp filter(query, :status, :open),
    do: Ash.Query.filter(query, status in [:draft, :confirmed, :in_progress])

  defp filter(query, :status, status), do: Ash.Query.filter(query, status == ^status)
  defp filter(query, :product_id, id), do: Ash.Query.filter(query, product_id == ^id)
end
