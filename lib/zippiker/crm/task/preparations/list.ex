defmodule Zippiker.Crm.Task.Preparations.List do
  @moduledoc "Applies the task view (open, today, overdue, ...) and record filters."
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    query
    |> view(Ash.Query.get_argument(query, :view))
    |> filter_by(:assignee_id, Ash.Query.get_argument(query, :assignee_id))
    |> filter_by(:party_id, Ash.Query.get_argument(query, :party_id))
    |> filter_by(:deal_id, Ash.Query.get_argument(query, :deal_id))
    |> filter_by(:lead_id, Ash.Query.get_argument(query, :lead_id))
  end

  defp view(query, :completed) do
    query |> Ash.Query.filter(not is_nil(completed_at)) |> Ash.Query.sort(completed_at: :desc)
  end

  defp view(query, view) do
    query
    |> open_filter(view)
    |> Ash.Query.sort([
      {:completed_at, :desc_nils_first},
      {:due_on, :asc_nils_last},
      {:inserted_at, :desc}
    ])
  end

  defp open_filter(query, :all), do: query
  defp open_filter(query, :open), do: Ash.Query.filter(query, is_nil(completed_at))

  defp open_filter(query, :today),
    do: Ash.Query.filter(query, is_nil(completed_at) and due_on <= today())

  defp open_filter(query, :overdue),
    do: Ash.Query.filter(query, is_nil(completed_at) and due_on < today())

  defp open_filter(query, :upcoming),
    do: Ash.Query.filter(query, is_nil(completed_at) and due_on > today())

  defp filter_by(query, _field, nil), do: query

  defp filter_by(query, :party_id, id),
    do:
      Ash.Query.filter(
        query,
        party_id == ^id or party.employer_id == ^id or deal.party_id == ^id or
          deal.company_id == ^id
      )

  defp filter_by(query, field, id), do: Ash.Query.filter(query, ^Ash.Expr.ref(field) == ^id)
end
