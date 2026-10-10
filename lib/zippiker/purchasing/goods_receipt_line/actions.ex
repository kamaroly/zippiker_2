defmodule Zippiker.Purchasing.GoodsReceiptLine.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:position, :description, :unit, :quantity, :product_id, :purchase_order_line_id]
    end
  end
end
