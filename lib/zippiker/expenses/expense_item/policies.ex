defmodule Zippiker.Expenses.ExpenseItem.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  # Items are only changed through their claim, which checks who may edit it.
  policies do
    # Roles: plain members need the permission covering the action
    # (Zippiker.Accounts.Permissions).
    policy action_type([:create, :update, :destroy, :action]) do
      forbid_unless Zippiker.Accounts.Checks.Permitted
      authorize_if always()
    end

    policy always() do
      authorize_if Zippiker.Accounts.Checks.ActorIsMember
    end
  end
end
