defmodule Zippiker.Inventory.Warehouse.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    has_many :movements, Zippiker.Inventory.StockMovement
  end
end
