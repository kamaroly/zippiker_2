defmodule Zippiker.Expenses.ExpenseCategory.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 60]
    attribute :description, :string, public?: true, constraints: [max_length: 500]

    attribute :receipt_required?, :boolean do
      description "Reminds claimants to keep a receipt for this kind of expense."
      allow_nil? false
      public? true
      default false
    end

    attribute :active?, :boolean, allow_nil?: false, public?: true, default: true
    timestamps()
  end
end
