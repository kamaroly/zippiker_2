defmodule Zippiker.Sales.Delivery.Preparations.Search do
  @moduledoc "Filters notes by number/customer/tracking text, status, order or invoice."
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    Enum.reduce([:query, :status, :sales_order_id, :invoice_id], query, fn argument, query ->
      filter(query, argument, Ash.Query.get_argument(query, argument))
    end)
  end

  defp filter(query, _argument, value) when value in [nil, ""], do: query

  defp filter(query, :query, term) do
    pattern = "%" <> String.replace(String.trim(term), ~r/[%_\\]/, "\\\\\\0") <> "%"

    Ash.Query.filter(
      query,
      ilike(number, ^pattern) or ilike(tracking_number, ^pattern) or
        ilike(customer.name, ^pattern) or ilike(sales_order.number, ^pattern)
    )
  end

  defp filter(query, :status, status), do: Ash.Query.filter(query, status == ^status)
  defp filter(query, :sales_order_id, id), do: Ash.Query.filter(query, sales_order_id == ^id)
  defp filter(query, :invoice_id, id), do: Ash.Query.filter(query, invoice_id == ^id)
end
