defmodule Zippiker.Purchasing.Bill.Changes.ReceiveUnorderedStock do
  @moduledoc """
  Stock-tracked lines that didn't come through a purchase order arrive with
  the bill: a goods received note and one stock receipt into the default
  warehouse at the bill's net unit price. (The bill's own entry carries the
  value, so the receipt posts nothing.)
  """
  use Ash.Resource.Change

  alias Zippiker.Purchasing.PurchaseOrderLine

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn changeset, bill ->
      opts = [tenant: changeset.tenant, authorize?: false]
      bill = Ash.load!(bill, [:supplier, lines: [:product]], opts)

      stocked =
        for line <- bill.lines,
            is_nil(line.received_unit_cost),
            line.product && line.product.track_inventory?,
            Decimal.gt?(line.quantity, 0),
            do: line

      lines =
        for line <- stocked do
          %{
            product_id: line.product_id,
            quantity: line.quantity,
            unit_cost: PurchaseOrderLine.unit_cost(line)
          }
        end

      if lines == [] do
        {:ok, bill}
      else
        case Zippiker.Inventory.record_stock_operation(
               %{
                 kind: :receipt,
                 date: bill.issued_on,
                 legal_entity_id: bill.legal_entity_id,
                 memo: "Billed by #{bill.supplier.name}",
                 source: :bill,
                 source_id: bill.id,
                 source_label: bill.number,
                 party_id: bill.supplier_id,
                 reference: bill.supplier_reference,
                 lines: lines
               },
               opts ++ [actor: context.actor]
             ) do
          {:ok, operation} ->
            with {:ok, _note} <-
                   write_note(bill, stocked, operation, opts ++ [actor: context.actor]),
                 do: {:ok, bill}

          error ->
            error
        end
      end
    end)
  end

  defp write_note(bill, lines, operation, opts) do
    Zippiker.Purchasing.record_goods_receipt(
      %{
        received_on: bill.issued_on,
        supplier_reference: bill.supplier_reference,
        legal_entity_id: bill.legal_entity_id,
        supplier_id: bill.supplier_id,
        bill_id: bill.id,
        warehouse_id: operation.warehouse_id,
        stock_operation_id: operation.id,
        lines:
          lines
          |> Enum.with_index()
          |> Enum.map(fn {line, index} ->
            %{
              position: index,
              description: line.description,
              unit: line.unit,
              quantity: line.quantity,
              product_id: line.product_id
            }
          end)
      },
      opts
    )
  end
end
