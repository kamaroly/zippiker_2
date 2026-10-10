defmodule Zippiker.Purchasing.PurchaseOrderLine.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    update :set_received do
      accept [:received_quantity]
    end
  end
end
