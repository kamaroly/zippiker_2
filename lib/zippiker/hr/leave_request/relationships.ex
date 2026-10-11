defmodule Zippiker.HR.LeaveRequest.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :employee, Zippiker.HR.Employee, allow_nil?: false, public?: true
    belongs_to :leave_type, Zippiker.HR.LeaveType, allow_nil?: false, public?: true

    belongs_to :approval_request, Zippiker.Workflow.ApprovalRequest do
      description "The workflow approval this request goes through (none if auto-approved)."
      public? true
      domain Zippiker.Workflow
    end

    belongs_to :decided_by, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end
  end
end
