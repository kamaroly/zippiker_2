defmodule Zippiker.Workflow.ApprovalStep do
  @moduledoc """
  One approver in a workflow: the initiator's manager, a specific user, any
  member of a group, or any workspace admin.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Workflow,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Workflow.ApprovalStep.Attributes,
      Zippiker.Workflow.ApprovalStep.Relationships,
      Zippiker.Workflow.ApprovalStep.Actions,
      Zippiker.Workflow.ApprovalGroup.Policies
    ]

  postgres do
    table "approval_steps"
    repo Zippiker.Repo

    references do
      reference :workflow, on_delete: :delete
      reference :user, on_delete: :nilify
      reference :group, on_delete: :nilify
    end
  end

  multitenancy do
    strategy :context
  end
end
