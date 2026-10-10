defmodule Zippiker.Expenses.ExpenseItem do
  @moduledoc "One receipt on an expense claim, in the claim's currency."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Expenses,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Expenses.ExpenseItem.Attributes,
      Zippiker.Expenses.ExpenseItem.Relationships,
      Zippiker.Expenses.ExpenseItem.Actions,
      Zippiker.Expenses.ExpenseItem.Policies
    ]

  postgres do
    table "expense_items"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :claim, on_delete: :delete
      reference :category, on_delete: :restrict
    end

    custom_indexes do
      index [:claim_id]
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end
end
