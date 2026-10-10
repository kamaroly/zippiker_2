defmodule Zippiker.Inventory.Reports.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    action :summary, :map do
      description "Stock value, tracked products, low and negative stock counts."
      run Zippiker.Inventory.Reports.Actions.Summary
    end

    action :levels, {:array, :map} do
      description "Each stock-tracked product with its quantity (in one warehouse or all)."
      argument :warehouse_id, :uuid
      argument :query, :string
      run Zippiker.Inventory.Reports.Actions.Levels
    end
  end
end
