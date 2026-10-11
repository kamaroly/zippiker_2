defmodule Zippiker.Accounts.Invitation.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  policies do
    # Roles: plain members need the permission covering the action
    # (Zippiker.Accounts.Permissions).
    policy action_type([:create, :update, :destroy, :action]) do
      forbid_unless Zippiker.Accounts.Checks.Permitted
      authorize_if always()
    end

    policy action([:for_me, :by_token, :accept]) do
      authorize_if actor_present()
    end

    policy action([:read, :pending, :create, :destroy]) do
      authorize_if Zippiker.Accounts.Checks.ActorIsAdmin
    end
  end
end
