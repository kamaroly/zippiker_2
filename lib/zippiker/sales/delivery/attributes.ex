defmodule Zippiker.Sales.Delivery.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :number, :string, public?: true
    attribute :shipped_on, :date, allow_nil?: false, public?: true, default: &Date.utc_today/0
    attribute :carrier, :string, public?: true, constraints: [max_length: 120]
    attribute :tracking_number, :string, public?: true, constraints: [max_length: 120]
    attribute :notes, :string, public?: true, constraints: [max_length: 2_000]

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :shipped
      constraints one_of: [:shipped, :delivered, :cancelled]
    end

    attribute :delivered_on, :date, public?: true
    attribute :received_by_name, :string, public?: true, constraints: [max_length: 120]

    timestamps()
  end
end
