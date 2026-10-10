defmodule Zippiker.Platform.BillingInvoice.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :number, :string, allow_nil?: false, public?: true

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :open
      constraints one_of: [:open, :paid, :void]
    end

    attribute :period_start, :date, allow_nil?: false, public?: true
    attribute :period_end, :date, allow_nil?: false, public?: true
    attribute :plan_name, :string, allow_nil?: false, public?: true
    attribute :seats, :integer, allow_nil?: false, public?: true
    attribute :unit_price, :decimal, allow_nil?: false, public?: true
    attribute :amount, :decimal, allow_nil?: false, public?: true
    attribute :currency, :string, allow_nil?: false, public?: true
    attribute :issued_on, :date, allow_nil?: false, public?: true
    attribute :due_on, :date, allow_nil?: false, public?: true
    attribute :paid_on, :date, public?: true

    timestamps()
  end
end
