defmodule Zippiker.Workflow.ApprovalGroup do
  @moduledoc "A named set of users (e.g. Finance); any member can decide a step assigned to the group."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Workflow,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Workflow.ApprovalGroup.Attributes,
      Zippiker.Workflow.ApprovalGroup.Relationships,
      Zippiker.Workflow.ApprovalGroup.Actions,
      Zippiker.Workflow.ApprovalGroup.Policies
    ]

  postgres do
    table "approval_groups"
    repo Zippiker.Repo
  end

  multitenancy do
    strategy :context
  end

  identities do
    identity :unique_name, [:name]
  end
end
