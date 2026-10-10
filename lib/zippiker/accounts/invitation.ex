defmodule Zippiker.Accounts.Invitation do
  @moduledoc """
  An invitation for an email address to join a workspace with a role.
  Accepting it (as a signed-in user with that email) creates the membership.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Accounts.Invitation.Attributes,
      Zippiker.Accounts.Invitation.Relationships,
      Zippiker.Accounts.Invitation.Actions,
      Zippiker.Accounts.Invitation.Policies
    ]

  postgres do
    table "invitations"
    repo Zippiker.Repo

    identity_wheres_to_sql unique_pending: "accepted_at IS NULL"

    references do
      reference :organization, on_delete: :delete
      reference :invited_by, on_delete: :nilify
    end
  end

  # `global?` lets an invitee look an invitation up by token or email
  # before they belong to the workspace.
  multitenancy do
    strategy :attribute
    attribute :organization_id
    global? true
  end

  identities do
    identity :unique_pending, [:organization_id, :email], where: expr(is_nil(accepted_at))
    identity :unique_token, [:token]
  end
end
