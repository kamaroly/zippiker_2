defmodule Zippiker.Accounts.PortalAccess do
  @moduledoc """
  Lets an outside person sign in to a team's customer or supplier portal
  for one party (a customer or supplier). Admins invite by email; the
  invitee claims it with the emailed link (`token`) once signed in. Kept in
  the shared schema (like invitations) so links and a person's portals can
  be looked up across teams.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Accounts.PortalAccess.Attributes,
      Zippiker.Accounts.PortalAccess.Relationships,
      Zippiker.Accounts.PortalAccess.Actions,
      Zippiker.Accounts.PortalAccess.Policies
    ]

  postgres do
    table "portal_accesses"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :user, on_delete: :nilify
      reference :invited_by, on_delete: :nilify
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
    global? true
  end

  identities do
    identity :unique_token, [:token]
  end
end
