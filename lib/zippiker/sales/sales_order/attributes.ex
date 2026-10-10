defmodule Zippiker.Sales.SalesOrder.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :number, :string, public?: true

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :draft
      constraints one_of: [:draft, :confirmed, :partially_delivered, :delivered, :cancelled]
    end

    attribute :issued_on, :date, allow_nil?: false, public?: true, default: &Date.utc_today/0
    attribute :expected_on, :date, public?: true, description: "Promised delivery date."
    attribute :currency, :string, allow_nil?: false, public?: true
    attribute :notes, :string, public?: true, constraints: [max_length: 5_000]
    attribute :subtotal, :money, public?: true
    attribute :tax_total, :money, public?: true
    attribute :total, :money, public?: true
    attribute :delivered_at, :utc_datetime_usec, public?: true

    timestamps()
  end
end
