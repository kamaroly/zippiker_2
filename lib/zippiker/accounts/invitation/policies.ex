defmodule Zippiker.Accounts.Invitation.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  policies do
    policy action([:for_me, :by_token, :accept]) do
      authorize_if actor_present()
    end

    policy action([:read, :pending, :create, :destroy]) do
      authorize_if Zippiker.Accounts.Checks.ActorIsAdmin
    end
  end
end
