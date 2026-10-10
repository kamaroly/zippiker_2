defmodule Zippiker.Workflow.ApprovalRequest do
  @moduledoc """
  A document going through its workflow. The workflow's steps are copied in
  when it starts; each step waits, then is pending (its approvers can decide),
  then approved, rejected or skipped (nobody to ask, or only the initiator).
  Approving the last step approves the request; any rejection rejects it.
  The document hears about the outcome via `Zippiker.Workflow.Callbacks`.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Workflow,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Workflow.ApprovalRequest.Attributes,
      Zippiker.Workflow.ApprovalRequest.Relationships,
      Zippiker.Workflow.ApprovalRequest.Actions,
      Zippiker.Workflow.ApprovalRequest.Policies
    ]

  postgres do
    table "approval_requests"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :workflow, on_delete: :nilify
      reference :requested_by, on_delete: :nilify
    end

    custom_indexes do
      index [:organization_id, :status]
      index [:organization_id, :document_type, :document_id]
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end
end
