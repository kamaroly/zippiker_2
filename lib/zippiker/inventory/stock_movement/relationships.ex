defmodule Zippiker.Inventory.StockMovement.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :operation, Zippiker.Inventory.StockOperation, allow_nil?: false, public?: true

    belongs_to :product, Zippiker.Catalog.Product do
      allow_nil? false
      public? true
      domain Zippiker.Catalog
    end

    belongs_to :warehouse, Zippiker.Inventory.Warehouse, allow_nil?: false, public?: true
  end
end
