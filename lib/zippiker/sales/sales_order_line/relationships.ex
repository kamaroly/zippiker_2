defmodule Zippiker.Sales.SalesOrderLine.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :sales_order, Zippiker.Sales.SalesOrder, allow_nil?: false, public?: true
  end
end
