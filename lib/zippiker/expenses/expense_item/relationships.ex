defmodule Zippiker.Expenses.ExpenseItem.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      domain Zippiker.Accounts
    end

    belongs_to :claim, Zippiker.Expenses.ExpenseClaim, allow_nil?: false, public?: true
    belongs_to :category, Zippiker.Expenses.ExpenseCategory, allow_nil?: false, public?: true
  end
end
