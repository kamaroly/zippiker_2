defmodule Zippiker.Sales.DeliveryLine.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :delivery, Zippiker.Sales.Delivery, allow_nil?: false, public?: true

    belongs_to :product, Zippiker.Catalog.Product do
      public? true
      domain Zippiker.Catalog
    end

    belongs_to :sales_order_line, Zippiker.Sales.SalesOrderLine, public?: true
  end
end
