defmodule Zippiker.Sales.Payment.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :amount, :money, allow_nil?: false, public?: true
    attribute :paid_on, :date, allow_nil?: false, public?: true, default: &Date.utc_today/0

    attribute :method, :atom do
      allow_nil? false
      public? true
      default :bank_transfer
      constraints one_of: [:bank_transfer, :card, :cash, :mobile_money, :cheque, :other]
    end

    attribute :reference, :string, public?: true, constraints: [max_length: 120]
    timestamps()
  end
end
