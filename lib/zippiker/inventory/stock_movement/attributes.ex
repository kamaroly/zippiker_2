defmodule Zippiker.Inventory.StockMovement.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :position, :integer, allow_nil?: false, public?: true, default: 0
    attribute :date, :date, allow_nil?: false, public?: true
    attribute :quantity, :decimal, allow_nil?: false, public?: true
    attribute :unit_cost, :decimal, allow_nil?: false, public?: true, default: 0
    create_timestamp :inserted_at
  end

  calculations do
    calculate :value, :decimal, expr(quantity * unit_cost), public?: true
  end
end
