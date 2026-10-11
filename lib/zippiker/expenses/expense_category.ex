defmodule Zippiker.Expenses.ExpenseCategory do
  @moduledoc "What an expense was for (travel, meals…) and the expense account it's booked to."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Expenses,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Expenses.ExpenseCategory.Attributes,
      Zippiker.Expenses.ExpenseCategory.Relationships,
      Zippiker.Expenses.ExpenseCategory.Actions,
      Zippiker.Expenses.ExpenseCategory.Policies
    ]

  postgres do
    table "expense_categories"
    repo Zippiker.Repo

    references do
      reference :account, on_delete: :nilify
    end
  end

  multitenancy do
    strategy :context
  end

  identities do
    identity :unique_name, [:name]
  end
end
