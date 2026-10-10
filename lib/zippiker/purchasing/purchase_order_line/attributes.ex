defmodule Zippiker.Purchasing.PurchaseOrderLine.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    attribute :received_quantity, :decimal do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end
  end
end
