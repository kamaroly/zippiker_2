defmodule Zippiker.Workflow do
  @moduledoc """
  Configurable approvals, reusable by any document (see
  `Zippiker.Workflow.DocumentTypes`; expense claims today).
  A workspace defines workflows per document type: an ordered list of steps
  (approver 1 … n, the last one being the final approver). Each step is
  decided by the initiator's manager, a specific user, anyone in an approval
  group, or any workspace admin. A request snapshots the steps when it starts.
  """
  use Ash.Domain, otp_app: :zippiker, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Zippiker.Workflow.ApprovalGroup do
      define :list_approval_groups, action: :list
      define :get_approval_group, action: :read, get_by: [:id]
      define :create_approval_group, action: :create
      define :update_approval_group, action: :update
      define :delete_approval_group, action: :destroy
    end

    resource Zippiker.Workflow.ApprovalGroupMember

    resource Zippiker.Workflow.ApprovalWorkflow do
      define :list_approval_workflows, action: :list
      define :get_approval_workflow, action: :read, get_by: [:id]
      define :create_approval_workflow, action: :create
      define :update_approval_workflow, action: :update
      define :delete_approval_workflow, action: :destroy
    end

    resource Zippiker.Workflow.ApprovalStep

    resource Zippiker.Workflow.ApprovalRequest do
      define :list_approval_requests, action: :search
      define :get_approval_request, action: :read, get_by: [:id]
      define :start_approval, action: :start
      define :decide_approval, action: :decide, args: [:decision]
      define :cancel_approval, action: :cancel
      define :approval_inbox, action: :inbox
    end

    resource Zippiker.Workflow.ApprovalRequestStep

    resource Zippiker.Workflow.ChangeRequest do
      define :list_change_requests, action: :search
      define :get_change_request, action: :read, get_by: [:id]
      define :request_change, action: :request
      define :cancel_change_request, action: :cancel

      define :apply_change_request,
        action: :apply_approval,
        args: [:change_request_id, :outcome]
    end
  end
end
