defmodule Zippiker.Sales.Invoice.Changes.CopySalesOrder do
  @moduledoc "Fills a new invoice from a confirmed or delivered sales order (once)."
  use Ash.Resource.Change

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
    id = Ash.Changeset.get_argument(changeset, :sales_order_id)
    opts = [tenant: changeset.tenant, authorize?: false, load: [:lines, :invoice]]

    case Zippiker.Sales.get_sales_order(id, opts) do
      {:ok, %{invoice: %{}}} ->
        Ash.Changeset.add_error(changeset,
          field: :sales_order_id,
          message: "this order was already invoiced"
        )

      {:ok, %{status: status}} when status in [:draft, :cancelled] ->
        Ash.Changeset.add_error(changeset,
          field: :sales_order_id,
          message: "confirm the order before invoicing it"
        )

      {:ok, order} ->
        changeset
        |> Ash.Changeset.force_change_attributes(%{
          sales_order_id: order.id,
          quote_id: order.quote_id,
          customer_id: order.customer_id,
          contact_id: order.contact_id,
          deal_id: order.deal_id,
          owner_id: order.owner_id,
          legal_entity_id: order.legal_entity_id,
          notes: order.notes
        })
        |> Ash.Changeset.set_argument(:lines, Enum.map(order.lines, &Map.take(&1, @line_fields)))

      {:error, _} ->
        Ash.Changeset.add_error(changeset, field: :sales_order_id, message: "order not found")
    end
  end
end
