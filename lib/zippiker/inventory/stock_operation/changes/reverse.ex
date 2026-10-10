defmodule Zippiker.Inventory.StockOperation.Changes.Reverse do
  @moduledoc "Copies an operation with every quantity negated, at the original unit costs."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    id = Ash.Changeset.get_argument(changeset, :operation_id)
    opts = [tenant: changeset.tenant, authorize?: false, load: [:movements, :reversal]]

    case Zippiker.Inventory.get_stock_operation(id, opts) do
      {:ok, %{reversal: nil, reversal_of_id: nil} = operation} ->
        changeset
        |> Ash.Changeset.force_change_attributes(%{
          kind: operation.kind,
          date: Date.utc_today(),
          memo: "Reversal of #{operation.number}",
          warehouse_id: operation.warehouse_id,
          legal_entity_id: operation.legal_entity_id,
          source: operation.source,
          source_id: operation.source_id,
          source_label: operation.source_label,
          party_id: operation.party_id,
          reversal_of_id: operation.id
        })
        |> Ash.Changeset.force_set_argument(
          :lines,
          Enum.map(operation.movements, fn movement ->
            %{
              signed: true,
              product_id: movement.product_id,
              quantity: Decimal.negate(movement.quantity),
              unit_cost: movement.unit_cost
            }
          end)
        )

      {:ok, _operation} ->
        Ash.Changeset.add_error(changeset,
          field: :operation_id,
          message: "already reversed (or itself a reversal)"
        )

      {:error, _} ->
        Ash.Changeset.add_error(changeset, field: :operation_id, message: "operation not found")
    end
  end
end
