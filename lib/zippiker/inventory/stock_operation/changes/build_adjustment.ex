defmodule Zippiker.Inventory.StockOperation.Changes.BuildAdjustment do
  @moduledoc "One product, signed quantity: + found / counted more, − damaged / lost."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.force_change_attributes(%{kind: :adjustment, source: :manual})
    |> Ash.Changeset.force_set_argument(:lines, [
      %{
        product_id: Ash.Changeset.get_argument(changeset, :product_id),
        quantity: Ash.Changeset.get_argument(changeset, :quantity),
        unit_cost: Ash.Changeset.get_argument(changeset, :unit_cost)
      }
    ])
  end
end
