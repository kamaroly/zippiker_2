defmodule Zippiker.Sales.Quote.Changes.WinDeal do
  @moduledoc "When a quote linked to an open deal is accepted, moves the deal to its pipeline's won stage."
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn changeset, quote ->
      opts = [tenant: changeset.tenant, actor: context.actor, authorize?: false]

      with deal_id when not is_nil(deal_id) <- quote.deal_id,
           {:ok, %{status: :open} = deal} <- Zippiker.Crm.get_deal(deal_id, opts),
           won when not is_nil(won) <- won_stage(deal.pipeline_id, opts) do
        Zippiker.Crm.move_deal!(deal, won.id, deal.position, opts)
      end

      {:ok, quote}
    end)
  end

  defp won_stage(pipeline_id, opts) do
    Zippiker.Crm.Stage
    |> Ash.Query.filter(pipeline_id == ^pipeline_id and kind == :won)
    |> Ash.Query.sort(position: :asc)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(opts)
  end
end
