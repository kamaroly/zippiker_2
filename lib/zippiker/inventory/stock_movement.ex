defmodule Zippiker.Inventory.StockMovement do
  @moduledoc """
  A signed quantity of one product in one warehouse (in > 0, out < 0) at a
  unit cost. Movements belong to a stock operation and are never changed.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Inventory.StockMovement.Attributes,
      Zippiker.Inventory.StockMovement.Relationships,
      Zippiker.Inventory.StockMovement.Actions,
      Zippiker.Inventory.StockMovement.Policies
    ]

  postgres do
    table "stock_movements"
    repo Zippiker.Repo

    references do
      reference :operation, on_delete: :delete
      reference :product, on_delete: :restrict
      reference :warehouse, on_delete: :restrict
    end

    custom_indexes do
      index [:product_id, :warehouse_id]
    end
  end

  multitenancy do
    strategy :context
  end
end
