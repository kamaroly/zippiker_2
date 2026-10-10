defmodule Zippiker.HR.Employee.Preparations.Search do
  @moduledoc "Filters by name/email/number/title text, department, manager and status."
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    Enum.reduce([:query, :department_id, :manager_id, :status], query, fn argument, query ->
      filter(query, argument, Ash.Query.get_argument(query, argument))
    end)
  end

  defp filter(query, _argument, value) when value in [nil, ""], do: query

  defp filter(query, :query, term) do
    pattern = "%" <> String.replace(String.trim(term), ~r/[%_\\]/, "\\\\\\0") <> "%"

    Ash.Query.filter(
      query,
      ilike(party.name, ^pattern) or ilike(type(party.email, :string), ^pattern) or
        ilike(employee_number, ^pattern) or ilike(job_title, ^pattern)
    )
  end

  defp filter(query, :department_id, id), do: Ash.Query.filter(query, department_id == ^id)
  defp filter(query, :manager_id, id), do: Ash.Query.filter(query, manager_id == ^id)
  defp filter(query, :status, status), do: Ash.Query.filter(query, status == ^status)
end
