defmodule Zippiker.Sales.Invoice.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :number, :string, public?: true

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :draft
      constraints one_of: [:draft, :issued, :paid, :void]
    end

    attribute :issued_on, :date, public?: true
    attribute :due_on, :date, public?: true
    attribute :currency, :string, allow_nil?: false, public?: true
    attribute :notes, :string, public?: true, constraints: [max_length: 5_000]
    attribute :subtotal, :money, public?: true
    attribute :tax_total, :money, public?: true
    attribute :total, :money, public?: true
    attribute :amount_paid, :money, public?: true
    attribute :paid_at, :utc_datetime_usec, public?: true
    attribute :voided_at, :utc_datetime_usec, public?: true

    timestamps()
  end
end
