defmodule Zippiker.Workflow.ApprovalRequestStep do
  @moduledoc "A step of a running approval: who should decide, and what happened."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Workflow,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Workflow.ApprovalRequestStep.Attributes,
      Zippiker.Workflow.ApprovalRequestStep.Relationships,
      Zippiker.Workflow.ApprovalRequestStep.Actions,
      Zippiker.Workflow.ApprovalRequest.Policies
    ]

  postgres do
    table "approval_request_steps"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :request, on_delete: :delete
      reference :user, on_delete: :nilify
      reference :group, on_delete: :nilify
      reference :decided_by, on_delete: :nilify
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end
end
