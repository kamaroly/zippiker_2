defmodule Zippiker.Accounts.MembershipRole.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  # Roles are given and taken through `Membership.set_roles` (admins only);
  # the join rows themselves are only written internally.
  policies do
    policy action_type(:read) do
      authorize_if expr(membership.user_id == ^actor(:id))
      authorize_if expr(exists(membership.organization.memberships, user_id == ^actor(:id)))
    end
  end
end
