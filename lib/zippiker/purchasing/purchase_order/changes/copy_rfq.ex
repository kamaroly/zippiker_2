defmodule Zippiker.Purchasing.PurchaseOrder.Changes.CopyRfq do
  @moduledoc """
  Fills a new purchase order from a request for quotation (supplier, lines at
  the quoted prices) and marks the request accepted.
  """
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
    id = Ash.Changeset.get_argument(changeset, :rfq_id)
    opts = [tenant: changeset.tenant, authorize?: false]

    case Zippiker.Purchasing.get_rfq(id, opts ++ [load: [:lines, :purchase_order]]) do
      {:ok, %{purchase_order: %{}}} ->
        Ash.Changeset.add_error(changeset,
          field: :rfq_id,
          message: "this request already has an order"
        )

      {:ok, %{status: :declined}} ->
        Ash.Changeset.add_error(changeset,
          field: :rfq_id,
          message: "declined requests can't be ordered"
        )

      {:ok, rfq} ->
        changeset
        |> Ash.Changeset.force_change_attributes(%{
          rfq_id: rfq.id,
          supplier_id: rfq.supplier_id,
          owner_id: rfq.owner_id,
          legal_entity_id: rfq.legal_entity_id,
          notes: rfq.notes
        })
        |> Ash.Changeset.set_argument(:lines, Enum.map(rfq.lines, &Map.take(&1, @line_fields)))
        |> Ash.Changeset.after_action(fn _changeset, order ->
          if rfq.status == :accepted do
            {:ok, order}
          else
            with {:ok, _rfq} <-
                   rfq
                   |> Ash.Changeset.for_update(:accept, %{}, opts)
                   |> Ash.update(authorize?: false),
                 do: {:ok, order}
          end
        end)

      {:error, _} ->
        Ash.Changeset.add_error(changeset, field: :rfq_id, message: "request not found")
    end
  end
end
