defmodule Zippiker.Catalog.Product.Calculations do
  use Spark.Dsl.Fragment, of: Ash.Resource

  calculations do
    calculate :stock_value, :decimal, expr(on_hand * average_cost) do
      description "On hand × average cost."
      public? true
    end

    calculate :low_stock?,
              :boolean,
              expr(track_inventory? and not is_nil(reorder_level) and on_hand <= reorder_level),
              public?: true
  end
end
