defmodule Zippiker.Sales.SalesOrder.Preparations.Search do
  @moduledoc "Filters orders by number/customer text, status, customer or deal."
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    Enum.reduce([:query, :status, :customer_id, :deal_id], query, fn argument, query ->
      filter(query, argument, Ash.Query.get_argument(query, argument))
    end)
  end

  defp filter(query, _argument, value) when value in [nil, ""], do: query

  defp filter(query, :query, term) do
    pattern = "%" <> String.replace(String.trim(term), ~r/[%_\\]/, "\\\\\\0") <> "%"
    Ash.Query.filter(query, ilike(number, ^pattern) or ilike(customer.name, ^pattern))
  end

  defp filter(query, :status, status), do: Ash.Query.filter(query, status == ^status)

  defp filter(query, :customer_id, id),
    do: Ash.Query.filter(query, customer_id == ^id or contact_id == ^id)

  defp filter(query, :deal_id, id), do: Ash.Query.filter(query, deal_id == ^id)
end
