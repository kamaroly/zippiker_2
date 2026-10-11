defmodule Zippiker.Accounts.Role.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  alias Zippiker.Accounts.Checks.{ActorIsAdmin, ActorIsMember, Permitted}

  policies do
    policy action_type([:create, :update, :destroy, :action]) do
      forbid_unless Permitted
      authorize_if always()
    end

    # Also without a tenant, e.g. loading a member's roles with their membership.
    policy action_type(:read) do
      authorize_if ActorIsMember
      authorize_if expr(exists(organization.memberships, user_id == ^actor(:id)))
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if ActorIsAdmin
    end

    policy action(:seed_defaults) do
      authorize_if ActorIsAdmin
    end
  end
end
