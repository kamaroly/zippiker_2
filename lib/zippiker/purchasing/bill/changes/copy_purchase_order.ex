defmodule Zippiker.Purchasing.Bill.Changes.CopyPurchaseOrder do
  @moduledoc """
  Fills a draft bill from a purchase order. Stock-tracked lines remember the
  order's unit cost (`received_unit_cost`) so the bill clears the "goods
  received not billed" account at the value the stock came in at.
  """
  use Ash.Resource.Change

  alias Zippiker.Purchasing.PurchaseOrderLine

  @line_fields [
    :position,
    :description,
    :quantity,
    :unit,
    :unit_price,
    :discount_percent,
    :tax_rate_id,
    :product_id
  ]

  @impl true
  def change(changeset, _opts, _context) do
    id = Ash.Changeset.get_argument(changeset, :purchase_order_id)
    opts = [tenant: changeset.tenant, authorize?: false, load: [:bill, lines: [:product]]]

    case Zippiker.Purchasing.get_purchase_order(id, opts) do
      {:ok, %{bill: %{}}} ->
        Ash.Changeset.add_error(changeset,
          field: :purchase_order_id,
          message: "this order was already billed"
        )

      {:ok, %{status: status}} when status in [:draft, :cancelled] ->
        Ash.Changeset.add_error(changeset,
          field: :purchase_order_id,
          message: "only placed orders can be billed"
        )

      {:ok, order} ->
        changeset
        |> Ash.Changeset.force_change_attributes(%{
          purchase_order_id: order.id,
          supplier_id: order.supplier_id,
          owner_id: order.owner_id,
          legal_entity_id: order.legal_entity_id,
          notes: order.notes
        })
        |> Ash.Changeset.set_argument(:lines, Enum.map(order.lines, &line/1))

      {:error, _} ->
        Ash.Changeset.add_error(changeset, field: :purchase_order_id, message: "order not found")
    end
  end

  defp line(line) do
    received_unit_cost =
      if line.product && line.product.track_inventory?, do: PurchaseOrderLine.unit_cost(line)

    line
    |> Map.take(@line_fields)
    |> Map.put(:received_unit_cost, received_unit_cost)
  end
end
