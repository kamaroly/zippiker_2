defmodule Zippiker.Expenses.ExpenseClaim.Changes.ComputeTotal do
  @moduledoc """
  After the items are saved, sums them into `total` (Money in the claim's
  currency). Must be declared after `manage_relationship(:items, ...)`.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, claim ->
      opts = [tenant: changeset.tenant, authorize?: false]
      claim = Ash.load!(claim, [:items], opts ++ [reuse_values?: false])
      total = Enum.reduce(claim.items, Decimal.new(0), &Decimal.add(&1.amount, &2))

      claim
      |> Ash.Changeset.for_update(:set_total, %{total: Money.new!(claim.currency, total)}, opts)
      |> Ash.update(authorize?: false)
      |> case do
        {:ok, updated} -> {:ok, %{updated | items: claim.items}}
        error -> error
      end
    end)
  end
end
