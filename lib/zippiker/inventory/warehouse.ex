defmodule Zippiker.Inventory.Warehouse do
  @moduledoc "A place where stock is kept. Every workspace gets a default one."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Inventory.Warehouse.Attributes,
      Zippiker.Inventory.Warehouse.Relationships,
      Zippiker.Inventory.Warehouse.Actions,
      Zippiker.Inventory.Warehouse.Policies
    ]

  postgres do
    table "warehouses"
    repo Zippiker.Repo
    identity_wheres_to_sql one_default: "\"default?\" = true"
  end

  multitenancy do
    strategy :context
  end

  identities do
    identity :unique_code, [:code]
    identity :one_default, [:default?], where: expr(default? == true)
  end
end
