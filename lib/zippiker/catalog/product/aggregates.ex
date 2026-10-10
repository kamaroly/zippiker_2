defmodule Zippiker.Catalog.Product.Aggregates do
  use Spark.Dsl.Fragment, of: Ash.Resource

  aggregates do
    sum :on_hand, :stock_movements, :quantity do
      description "Quantity in stock across all warehouses."
      public? true
      default 0
    end
  end
end
