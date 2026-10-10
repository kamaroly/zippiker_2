defmodule Zippiker.Expenses.ExpenseClaim.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :number, :string, public?: true
    attribute :title, :string, allow_nil?: false, public?: true, constraints: [max_length: 120]
    attribute :notes, :string, public?: true, constraints: [max_length: 2_000]

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :draft
      constraints one_of: [:draft, :submitted, :approved, :rejected, :reimbursed, :cancelled]
    end

    attribute :currency, :string, allow_nil?: false, public?: true
    attribute :total, :money, public?: true
    attribute :submitted_at, :utc_datetime_usec, public?: true
    attribute :approved_at, :utc_datetime_usec, public?: true
    attribute :rejected_at, :utc_datetime_usec, public?: true

    attribute :reimbursed_on, :date, public?: true

    attribute :reimbursed_from, :atom do
      description "Where the money came from when the claimant was paid back."
      public? true
      constraints one_of: [:cash, :bank, :mobile_money]
    end

    attribute :reimbursement_reference, :string, public?: true, constraints: [max_length: 60]

    timestamps()
  end
end
