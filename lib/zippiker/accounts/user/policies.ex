defmodule Zippiker.Accounts.User.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy action([:platform_search, :set_super_admin]) do
      authorize_if Zippiker.Accounts.Checks.ActorIsSuperAdmin
    end

    policy action(:read) do
      authorize_if Zippiker.Accounts.Checks.ActorIsSuperAdmin
      authorize_if expr(id == ^actor(:id))
      authorize_if expr(exists(memberships.organization.memberships, user_id == ^actor(:id)))
    end

    policy action(:update_profile) do
      authorize_if expr(id == ^actor(:id))
    end
  end
end
