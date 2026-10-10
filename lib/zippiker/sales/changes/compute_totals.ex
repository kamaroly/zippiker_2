defmodule Zippiker.Sales.Changes.ComputeTotals do
  @moduledoc """
  After lines are saved, sums them into the document's `subtotal`,
  `tax_total` and `total` (as Money in the document currency).
  Must be declared after `manage_relationship(:lines, ...)`.
  """
  use Ash.Resource.Change

  alias Zippiker.Sales.Pricing

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, document ->
      opts = [tenant: changeset.tenant, authorize?: false]
      document = Ash.load!(document, [:lines], opts ++ [reuse_values?: false])
      totals = Pricing.totals(document.lines)
      money = &Money.new!(document.currency, &1)

      document
      |> Ash.Changeset.for_update(
        :set_totals,
        %{
          subtotal: money.(totals.subtotal),
          tax_total: money.(totals.tax_amount),
          total: money.(totals.total)
        },
        opts
      )
      |> Ash.update()
      |> case do
        {:ok, updated} -> {:ok, %{updated | lines: document.lines}}
        error -> error
      end
    end)
  end
end
