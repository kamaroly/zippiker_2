defmodule Zippiker.Catalog.Product.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 200]
    attribute :sku, :string, public?: true, constraints: [max_length: 60]
    attribute :description, :string, public?: true, constraints: [max_length: 2_000]

    attribute :kind, :atom do
      allow_nil? false
      public? true
      default :service
      constraints one_of: [:service, :goods]
    end

    attribute :unit, :string do
      description "Unit of measure shown on documents, e.g. hour, pcs, month."
      allow_nil? false
      public? true
      default "unit"
      constraints max_length: 20
    end

    attribute :unit_price, :decimal do
      description "Default selling price in the workspace currency."
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :active?, :boolean, allow_nil?: false, public?: true, default: true

    attribute :track_inventory?, :boolean do
      description "Goods whose quantity on hand is tracked (see `Zippiker.Inventory`)."
      allow_nil? false
      public? true
      default false
    end

    attribute :cost_price, :decimal do
      description "Default purchase price, used on purchase orders and bills."
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :average_cost, :decimal do
      description "Weighted average cost of the stock on hand. Maintained by inventory."
      allow_nil? false
      public? true
      default 0
    end

    attribute :reorder_level, :decimal do
      description "Warn when stock on hand falls to this quantity."
      public? true
      constraints min: 0
    end

    timestamps()
  end
end
