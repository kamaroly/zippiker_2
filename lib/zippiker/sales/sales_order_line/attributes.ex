defmodule Zippiker.Sales.SalesOrderLine.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    attribute :delivered_quantity, :decimal do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end
  end
end
