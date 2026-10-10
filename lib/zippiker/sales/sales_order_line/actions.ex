defmodule Zippiker.Sales.SalesOrderLine.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    update :set_delivered do
      accept [:delivered_quantity]
    end
  end
end
