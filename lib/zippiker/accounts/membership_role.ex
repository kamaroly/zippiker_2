defmodule Zippiker.Accounts.MembershipRole do
  @moduledoc "A role given to a member of a workspace."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Accounts.MembershipRole.Attributes,
      Zippiker.Accounts.MembershipRole.Relationships,
      Zippiker.Accounts.MembershipRole.Actions,
      Zippiker.Accounts.MembershipRole.Policies
    ]

  postgres do
    table "membership_roles"
    repo Zippiker.Repo

    references do
      reference :membership, on_delete: :delete
      reference :role, on_delete: :delete
    end
  end

  identities do
    identity :unique_role, [:membership_id, :role_id]
  end
end
