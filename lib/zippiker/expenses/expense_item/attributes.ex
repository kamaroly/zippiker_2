defmodule Zippiker.Expenses.ExpenseItem.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :position, :integer, allow_nil?: false, public?: true, default: 0
    attribute :spent_on, :date, allow_nil?: false, public?: true, default: &Date.utc_today/0

    attribute :description, :string,
      allow_nil?: false,
      public?: true,
      constraints: [max_length: 200]

    attribute :merchant, :string, public?: true, constraints: [max_length: 120]

    attribute :amount, :decimal do
      allow_nil? false
      public? true
      constraints min: 0
    end

    timestamps()
  end
end
