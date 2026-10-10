defmodule Zippiker.Expenses.ExpenseClaim.Preparations.Search do
  @moduledoc "Filters claims by number/title/claimant text, status, claimant, or the actor's own."
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, context) do
    query =
      if Ash.Query.get_argument(query, :mine?) do
        actor_id = context.actor && context.actor.id
        Ash.Query.filter(query, claimant_id == ^actor_id)
      else
        query
      end

    Enum.reduce([:query, :status, :claimant_id], query, fn argument, query ->
      filter(query, argument, Ash.Query.get_argument(query, argument))
    end)
  end

  defp filter(query, _argument, value) when value in [nil, ""], do: query

  defp filter(query, :query, term) do
    pattern = "%" <> String.replace(String.trim(term), ~r/[%_\\]/, "\\\\\\0") <> "%"

    Ash.Query.filter(
      query,
      ilike(number, ^pattern) or ilike(title, ^pattern) or ilike(claimant.name, ^pattern)
    )
  end

  defp filter(query, :status, status), do: Ash.Query.filter(query, status == ^status)
  defp filter(query, :claimant_id, id), do: Ash.Query.filter(query, claimant_id == ^id)
end
