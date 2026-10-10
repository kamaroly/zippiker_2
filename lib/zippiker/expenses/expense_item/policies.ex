defmodule Zippiker.Expenses.ExpenseItem.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  # Items are only changed through their claim, which checks who may edit it.
  policies do
    policy always() do
      authorize_if Zippiker.Accounts.Checks.ActorIsMember
    end
  end
end
