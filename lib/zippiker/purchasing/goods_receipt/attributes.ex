defmodule Zippiker.Purchasing.GoodsReceipt.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :number, :string, public?: true
    attribute :received_on, :date, allow_nil?: false, public?: true, default: &Date.utc_today/0

    attribute :supplier_reference, :string do
      description "The supplier's delivery note / waybill number."
      public? true
      constraints max_length: 120
    end

    attribute :notes, :string, public?: true, constraints: [max_length: 2_000]

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :received
      constraints one_of: [:received, :cancelled]
    end

    timestamps()
  end
end
