defmodule Zippiker.Purchasing.RfqLine do
  @moduledoc "A line on a request for quotation."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Purchasing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Sales.DocumentLine.Attributes,
      Zippiker.Sales.DocumentLine.Actions,
      Zippiker.Purchasing.RfqLine.Relationships,
      Zippiker.Sales.DocumentLine.Policies
    ]

  postgres do
    table "rfq_lines"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :rfq, on_delete: :delete
      reference :product, on_delete: :nilify
      reference :tax_rate, on_delete: :nilify
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end
end
