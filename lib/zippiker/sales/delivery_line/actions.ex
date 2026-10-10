defmodule Zippiker.Sales.DeliveryLine.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:position, :description, :unit, :quantity, :product_id, :sales_order_line_id]
    end
  end
end
