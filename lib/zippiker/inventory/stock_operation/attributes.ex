defmodule Zippiker.Inventory.StockOperation.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :number, :string, public?: true

    attribute :kind, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:receipt, :delivery, :adjustment]
    end

    attribute :date, :date, allow_nil?: false, public?: true, default: &Date.utc_today/0
    attribute :memo, :string, public?: true, constraints: [max_length: 500]

    attribute :source, :atom do
      description "The document that caused the movement."
      allow_nil? false
      public? true
      default :manual
      constraints one_of: [:manual, :purchase_order, :bill, :sales_order, :invoice]
    end

    attribute :source_id, :uuid, public?: true
    attribute :source_label, :string, public?: true, constraints: [max_length: 60]

    attribute :reference, :string do
      description "The other side's paperwork: supplier's delivery note, carrier tracking number…"
      public? true
      constraints max_length: 120
    end

    attribute :total_value, :decimal do
      description "Value of the goods moved (quantity × unit cost, absolute)."
      allow_nil? false
      public? true
      default 0
    end

    timestamps()
  end
end
