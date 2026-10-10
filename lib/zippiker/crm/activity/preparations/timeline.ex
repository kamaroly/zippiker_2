defmodule Zippiker.Crm.Activity.Preparations.Timeline do
  @moduledoc "Filters activities for whichever record id was given."
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    query = Ash.Query.limit(query, Ash.Query.get_argument(query, :limit))

    case Map.take(query.arguments, [:party_id, :deal_id, :lead_id]) |> Enum.find(&elem(&1, 1)) do
      {:party_id, id} ->
        Ash.Query.filter(
          query,
          party_id == ^id or party.employer_id == ^id or deal.party_id == ^id or
            deal.company_id == ^id
        )

      {:deal_id, id} ->
        Ash.Query.filter(query, deal_id == ^id)

      {:lead_id, id} ->
        Ash.Query.filter(query, lead_id == ^id)

      nil ->
        query
    end
  end
end
