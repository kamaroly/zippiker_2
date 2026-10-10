defmodule Zippiker.Purchasing.GoodsReceipt.Preparations.Search do
  @moduledoc "Filters notes by number/supplier/reference text, purchase order or bill."
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    Enum.reduce([:query, :purchase_order_id, :bill_id], query, fn argument, query ->
      filter(query, argument, Ash.Query.get_argument(query, argument))
    end)
  end

  defp filter(query, _argument, value) when value in [nil, ""], do: query

  defp filter(query, :query, term) do
    pattern = "%" <> String.replace(String.trim(term), ~r/[%_\\]/, "\\\\\\0") <> "%"

    Ash.Query.filter(
      query,
      ilike(number, ^pattern) or ilike(supplier_reference, ^pattern) or
        ilike(supplier.name, ^pattern) or ilike(purchase_order.number, ^pattern)
    )
  end

  defp filter(query, :purchase_order_id, id),
    do: Ash.Query.filter(query, purchase_order_id == ^id)

  defp filter(query, :bill_id, id), do: Ash.Query.filter(query, bill_id == ^id)
end
