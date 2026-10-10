defmodule Zippiker.Manufacturing.ProductionOrder do
  @moduledoc """
  Make `quantity` of a product from its bill of materials:
  draft → confirmed → in progress (some output recorded) → done, or
  cancelled before anything is produced. Each recorded output consumes the
  components from stock and receives the finished goods at cost in a
  `:production` stock operation (posted to the books).
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Manufacturing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Manufacturing.ProductionOrder.Attributes,
      Zippiker.Manufacturing.ProductionOrder.Relationships,
      Zippiker.Manufacturing.ProductionOrder.Actions,
      Zippiker.Manufacturing.ProductionOrder.Policies
    ]

  postgres do
    table "production_orders"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :legal_entity, on_delete: :restrict
      reference :product, on_delete: :restrict
      reference :bom, on_delete: :restrict
      reference :warehouse, on_delete: :nilify
      reference :owner, on_delete: :nilify
    end

    custom_indexes do
      index [:organization_id, :status]
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end
end
