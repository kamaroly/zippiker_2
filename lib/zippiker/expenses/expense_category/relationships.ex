defmodule Zippiker.Expenses.ExpenseCategory.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      domain Zippiker.Accounts
    end

    belongs_to :account, Zippiker.Accounting.Account do
      description "Expense account to debit; empty = Other expenses."
      public? true
      domain Zippiker.Accounting
    end
  end
end
