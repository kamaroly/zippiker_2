defmodule Zippiker.Crm.Deal.Preparations.Search do
  @moduledoc "Optional filters for the deal list."
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    Enum.reduce([:query, :status, :party_id, :owner_id], query, fn argument, query ->
      filter(query, argument, Ash.Query.get_argument(query, argument))
    end)
  end

  defp filter(query, _argument, value) when value in [nil, ""], do: query

  defp filter(query, :query, term) do
    pattern = "%" <> String.replace(String.trim(term), ~r/[%_\\]/, "\\\\\\0") <> "%"
    Ash.Query.filter(query, ilike(title, ^pattern) or ilike(company.name, ^pattern))
  end

  defp filter(query, :status, status), do: Ash.Query.filter(query, status == ^status)

  defp filter(query, :party_id, id),
    do: Ash.Query.filter(query, party_id == ^id or company_id == ^id)

  defp filter(query, :owner_id, id), do: Ash.Query.filter(query, owner_id == ^id)
end
