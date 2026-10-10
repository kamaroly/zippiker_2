defmodule Zippiker.Inventory.StockOperation.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Inventory.StockOperation.Changes

  actions do
    defaults [:read]

    read :search do
      argument :kind, :atom, constraints: [one_of: [:receipt, :delivery, :adjustment]]
      argument :source, :atom
      argument :source_id, :uuid
      prepare Zippiker.Inventory.StockOperation.Preparations.Search
      prepare build(sort: [date: :desc, number: :desc], load: [:warehouse, :reversal])
      pagination offset?: true, countable: true, default_limit: 25, required?: false
    end

    create :record do
      description "Moves stock for a document (lines: product_id, quantity, unit_cost)."

      accept [
        :kind,
        :date,
        :warehouse_id,
        :memo,
        :source,
        :source_id,
        :source_label,
        :legal_entity_id,
        :party_id,
        :reference
      ]

      argument :lines, {:array, :map}, default: []

      change Changes.SetDefaults
      change relate_actor(:created_by, allow_nil?: true)
      change Changes.PrepareMovements
      change manage_relationship(:lines, :movements, type: :create)
      change Changes.AssignNumber
      change Changes.UpdateAverageCost
      change Changes.PostToLedger
    end

    create :adjust do
      description "Corrects stock on hand after a count, damage or loss (signed quantity)."
      accept [:date, :warehouse_id, :memo, :reference]
      argument :product_id, :uuid, allow_nil?: false
      argument :quantity, :decimal, allow_nil?: false
      argument :unit_cost, :decimal, constraints: [min: 0]
      argument :lines, {:array, :map}, default: []

      change Changes.BuildAdjustment
      change Changes.SetDefaults
      change relate_actor(:created_by, allow_nil?: true)
      change Changes.PrepareMovements
      change manage_relationship(:lines, :movements, type: :create)
      change Changes.AssignNumber
      change Changes.UpdateAverageCost
      change Changes.PostToLedger
    end

    create :reverse do
      description "Undoes an operation with opposite movements at the same costs."
      argument :operation_id, :uuid, allow_nil?: false
      argument :lines, {:array, :map}, default: []

      change Changes.Reverse
      change Changes.SetDefaults
      change relate_actor(:created_by, allow_nil?: true)
      change Changes.PrepareMovements
      change manage_relationship(:lines, :movements, type: :create)
      change Changes.AssignNumber
      change Changes.UpdateAverageCost
      change Changes.PostToLedger
    end
  end
end
