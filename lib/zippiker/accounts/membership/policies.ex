defmodule Zippiker.Accounts.Membership.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  policies do
    bypass action_type(:read) do
      authorize_if Zippiker.Accounts.Checks.ActorIsSuperAdmin
    end

    policy action_type(:read) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if expr(exists(organization.memberships, user_id == ^actor(:id)))
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if Zippiker.Accounts.Checks.ActorIsAdmin
    end
  end
end
