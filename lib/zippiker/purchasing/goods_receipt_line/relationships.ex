defmodule Zippiker.Purchasing.GoodsReceiptLine.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :goods_receipt, Zippiker.Purchasing.GoodsReceipt, allow_nil?: false, public?: true

    belongs_to :product, Zippiker.Catalog.Product do
      public? true
      domain Zippiker.Catalog
    end

    belongs_to :purchase_order_line, Zippiker.Purchasing.PurchaseOrderLine, public?: true
  end
end
