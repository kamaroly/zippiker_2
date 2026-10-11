defmodule Zippiker.Catalog.TaxRate do
  @moduledoc "A named tax percentage, e.g. `VAT 18%`. Document lines snapshot the percentage."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshArchival.Resource],
    fragments: [
      Zippiker.Catalog.TaxRate.Attributes,
      Zippiker.Catalog.TaxRate.Relationships,
      Zippiker.Catalog.TaxRate.Actions,
      Zippiker.Catalog.TaxRate.Policies
    ]

  postgres do
    table "tax_rates"
    repo Zippiker.Repo
  end

  multitenancy do
    strategy :context
  end
end
