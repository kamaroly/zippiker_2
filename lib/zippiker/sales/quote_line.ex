defmodule Zippiker.Sales.QuoteLine do
  @moduledoc "A line on a quote. Amounts are priced by `Zippiker.Sales.Changes.PriceLine`."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Sales,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Sales.DocumentLine.Attributes,
      Zippiker.Sales.DocumentLine.Actions,
      Zippiker.Sales.QuoteLine.Relationships,
      Zippiker.Sales.DocumentLine.Policies
    ]

  postgres do
    table "quote_lines"
    repo Zippiker.Repo

    references do
      reference :quote, on_delete: :delete
      reference :product, on_delete: :nilify
      reference :tax_rate, on_delete: :nilify
    end
  end

  multitenancy do
    strategy :context
  end
end
