defmodule Zippiker.Catalog.Product do
  @moduledoc "A product or service with a default price, unit and tax rate."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshArchival.Resource, Zippiker.Extensibility.CustomFields],
    fragments: [
      Zippiker.Catalog.Product.Attributes,
      Zippiker.Catalog.Product.Relationships,
      Zippiker.Catalog.Product.Aggregates,
      Zippiker.Catalog.Product.Calculations,
      Zippiker.Catalog.Product.Actions,
      Zippiker.Catalog.Product.Policies
    ]

  postgres do
    table "products"
    repo Zippiker.Repo

    identity_wheres_to_sql unique_sku: "archived_at IS NULL AND sku IS NOT NULL"

    references do
      reference :organization, on_delete: :delete
      reference :tax_rate, on_delete: :nilify
    end

    custom_indexes do
      index [:organization_id, :name]
    end
  end

  custom_fields do
    entity(:product)
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  identities do
    identity :unique_sku, [:sku], where: expr(is_nil(archived_at) and not is_nil(sku))
  end
end
