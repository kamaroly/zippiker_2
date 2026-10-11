defmodule Zippiker.Sales.DeliveryLine do
  @moduledoc "One item on a delivery note."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Sales,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Sales.DeliveryLine.Attributes,
      Zippiker.Sales.DeliveryLine.Relationships,
      Zippiker.Sales.DeliveryLine.Actions,
      Zippiker.Sales.DocumentLine.Policies
    ]

  postgres do
    table "delivery_lines"
    repo Zippiker.Repo

    references do
      reference :delivery, on_delete: :delete
      reference :product, on_delete: :nilify
      reference :sales_order_line, on_delete: :nilify
    end
  end

  multitenancy do
    strategy :context
  end
end
