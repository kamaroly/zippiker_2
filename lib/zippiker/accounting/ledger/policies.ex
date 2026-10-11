defmodule Zippiker.Accounting.Ledger.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  # Postings are made by other modules' actions with `authorize?: false`;
  # people can only set up the books and run the sync.
  policies do
    # Roles: plain members need the permission covering the action
    # (Zippiker.Accounts.Permissions).
    policy action_type([:create, :update, :destroy, :action]) do
      forbid_unless Zippiker.Accounts.Checks.Permitted
      authorize_if always()
    end

    policy action([:setup, :sync_sales]) do
      authorize_if Zippiker.Accounts.Checks.ActorIsAdmin
    end
  end
end
