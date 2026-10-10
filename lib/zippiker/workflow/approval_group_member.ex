defmodule Zippiker.Workflow.ApprovalGroupMember do
  @moduledoc "A user in an approval group."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Workflow,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Workflow.ApprovalGroupMember.Attributes,
      Zippiker.Workflow.ApprovalGroupMember.Relationships,
      Zippiker.Workflow.ApprovalGroupMember.Actions,
      Zippiker.Workflow.ApprovalGroup.Policies
    ]

  postgres do
    table "approval_group_members"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :group, on_delete: :delete
      reference :user, on_delete: :delete
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  identities do
    identity :unique_member, [:group_id, :user_id]
  end
end
