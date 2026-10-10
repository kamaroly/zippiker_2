defmodule Zippiker.Crm.Lead.Preparations.Search do
  @moduledoc "Optional free-text and status filters for the lead list."
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    query
    |> filter_query(Ash.Query.get_argument(query, :query))
    |> filter_status(Ash.Query.get_argument(query, :status))
  end

  defp filter_query(query, term) when is_binary(term) and term != "" do
    pattern = "%" <> String.replace(String.trim(term), ~r/[%_\\]/, "\\\\\\0") <> "%"

    Ash.Query.filter(
      query,
      ilike(name, ^pattern) or ilike(company_name, ^pattern) or ilike(email, ^pattern)
    )
  end

  defp filter_query(query, _term), do: query

  defp filter_status(query, nil), do: Ash.Query.filter(query, status != :converted)
  defp filter_status(query, :all), do: query
  defp filter_status(query, status), do: Ash.Query.filter(query, status == ^status)
end
