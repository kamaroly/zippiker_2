defmodule Zippiker.Accounts.Organization.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  alias Zippiker.Accounts.Checks.ActorIsSuperAdmin

  policies do
    bypass ActorIsSuperAdmin do
      authorize_if always()
    end

    policy action([:set_plan_limits, :platform_search]) do
      forbid_if always()
    end

    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type(:read) do
      authorize_if expr(exists(memberships, user_id == ^actor(:id)))
    end

    policy action_type(:update) do
      authorize_if expr(exists(memberships, user_id == ^actor(:id) and role in [:owner, :admin]))
    end
  end
end
