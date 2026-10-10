defmodule Zippiker.Purchasing.PurchaseOrder.Preparations.Search do
  @moduledoc "Filters orders by number/supplier text, status (`:open` = still to receive) and supplier."
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    Enum.reduce([:query, :status, :supplier_id], query, fn argument, query ->
      filter(query, argument, Ash.Query.get_argument(query, argument))
    end)
  end

  defp filter(query, _argument, value) when value in [nil, ""], do: query

  defp filter(query, :query, term) do
    pattern = "%" <> String.replace(String.trim(term), ~r/[%_\\]/, "\\\\\\0") <> "%"
    Ash.Query.filter(query, ilike(number, ^pattern) or ilike(supplier.name, ^pattern))
  end

  defp filter(query, :status, :open),
    do: Ash.Query.filter(query, status in [:ordered, :partially_received])

  defp filter(query, :status, status), do: Ash.Query.filter(query, status == ^status)
  defp filter(query, :supplier_id, id), do: Ash.Query.filter(query, supplier_id == ^id)
end
