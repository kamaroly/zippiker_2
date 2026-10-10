defmodule Zippiker.Platform.Plan.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  policies do
    policy action_type(:read) do
      authorize_if actor_present()
    end

    policy action_type([:create, :update]) do
      authorize_if Zippiker.Accounts.Checks.ActorIsSuperAdmin
    end
  end
end
