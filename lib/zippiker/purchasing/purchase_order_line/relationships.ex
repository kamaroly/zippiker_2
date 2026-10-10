defmodule Zippiker.Purchasing.PurchaseOrderLine.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :purchase_order, Zippiker.Purchasing.PurchaseOrder,
      allow_nil?: false,
      public?: true
  end
end
