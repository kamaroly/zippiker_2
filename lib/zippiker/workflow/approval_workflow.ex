defmodule Zippiker.Workflow.ApprovalWorkflow do
  @moduledoc """
  The approval route for a document type (e.g. expense claims): an ordered
  list of steps, the last being the final approver. Several workflows can
  exist per type; the one with the highest `min_amount` not above the
  document's amount applies (so big claims can need more approvers).
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Workflow,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Workflow.ApprovalWorkflow.Attributes,
      Zippiker.Workflow.ApprovalWorkflow.Relationships,
      Zippiker.Workflow.ApprovalWorkflow.Actions,
      Zippiker.Workflow.ApprovalGroup.Policies
    ]

  postgres do
    table "approval_workflows"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end
end
