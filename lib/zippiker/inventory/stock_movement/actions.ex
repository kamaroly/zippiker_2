defmodule Zippiker.Inventory.StockMovement.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    read :for_product do
      description "A product's stock history, newest first."
      argument :product_id, :uuid, allow_nil?: false
      filter expr(product_id == ^arg(:product_id))

      prepare build(
                sort: [date: :desc, inserted_at: :desc],
                load: [:operation, :warehouse, :value]
              )
    end

    create :create do
      primary? true
      accept [:product_id, :warehouse_id, :date, :quantity, :unit_cost, :position]
    end
  end
end
