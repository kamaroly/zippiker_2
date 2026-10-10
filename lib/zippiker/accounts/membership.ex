defmodule Zippiker.Accounts.Membership do
  @moduledoc "Links a user to an organization with a role."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Accounts.Membership.Attributes,
      Zippiker.Accounts.Membership.Relationships,
      Zippiker.Accounts.Membership.Actions,
      Zippiker.Accounts.Membership.Policies
    ]

  postgres do
    table "memberships"
    repo Zippiker.Repo

    references do
      reference :user, on_delete: :delete
      reference :organization, on_delete: :delete
    end
  end

  identities do
    identity :unique_member, [:user_id, :organization_id]
  end
end
