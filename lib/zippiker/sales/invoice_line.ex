defmodule Zippiker.Sales.InvoiceLine do
  @moduledoc "A line on a invoice. Amounts are priced by `Zippiker.Sales.Changes.PriceLine`."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Sales,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Sales.DocumentLine.Attributes,
      Zippiker.Sales.DocumentLine.Actions,
      Zippiker.Sales.InvoiceLine.Relationships,
      Zippiker.Sales.DocumentLine.Policies
    ]

  postgres do
    table "invoice_lines"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :invoice, on_delete: :delete
      reference :product, on_delete: :nilify
      reference :tax_rate, on_delete: :nilify
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end
end
