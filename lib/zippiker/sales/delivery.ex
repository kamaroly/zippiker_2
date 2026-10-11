defmodule Zippiker.Sales.Delivery do
  @moduledoc """
  A delivery note (`DN-2026-0001`): what left for a customer, from which
  warehouse, for which order or invoice, with the carrier and tracking number.
  Shipped → delivered once the customer confirms receipt (who signed, when).
  Stock-tracked lines also move stock (`stock_operation`).
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Sales,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Sales.Delivery.Attributes,
      Zippiker.Sales.Delivery.Relationships,
      Zippiker.Sales.Delivery.Actions,
      Zippiker.Sales.Delivery.Policies
    ]

  postgres do
    table "deliveries"
    repo Zippiker.Repo

    references do
      reference :legal_entity, on_delete: :restrict
      reference :customer, on_delete: :restrict
      reference :sales_order, on_delete: :nilify
      reference :invoice, on_delete: :nilify
      reference :warehouse, on_delete: :nilify
      reference :shipped_by, on_delete: :nilify
      reference :stock_operation, on_delete: :nilify
    end

    custom_indexes do
      index [:shipped_on]
      index [:sales_order_id]
      index [:status]
    end
  end

  multitenancy do
    strategy :context
  end
end
