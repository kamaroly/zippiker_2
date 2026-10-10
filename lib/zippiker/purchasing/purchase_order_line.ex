defmodule Zippiker.Purchasing.PurchaseOrderLine do
  @moduledoc "A line on a purchase order; tracks how much has been received."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Purchasing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Sales.DocumentLine.Attributes,
      Zippiker.Sales.DocumentLine.Actions,
      Zippiker.Purchasing.PurchaseOrderLine.Attributes,
      Zippiker.Purchasing.PurchaseOrderLine.Relationships,
      Zippiker.Purchasing.PurchaseOrderLine.Actions,
      Zippiker.Sales.DocumentLine.Policies
    ]

  postgres do
    table "purchase_order_lines"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :purchase_order, on_delete: :delete
      reference :product, on_delete: :nilify
      reference :tax_rate, on_delete: :nilify
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  @doc "Quantity still to arrive."
  def remaining(line), do: Decimal.sub(line.quantity, line.received_quantity)

  @doc "Net cost per unit (after discount, before tax): what goes into stock."
  def unit_cost(%{quantity: quantity} = line) do
    if Decimal.gt?(quantity, 0),
      do: line.subtotal |> Decimal.div(quantity) |> Decimal.round(6),
      else: Decimal.new(0)
  end
end
