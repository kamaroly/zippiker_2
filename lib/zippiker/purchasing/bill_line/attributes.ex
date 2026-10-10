defmodule Zippiker.Purchasing.BillLine.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    attribute :received_unit_cost, :decimal do
      description "Unit cost the goods were received at on the purchase order."
      public? true
    end
  end
end
