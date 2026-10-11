defmodule Zippiker.HR.LeaveRequest do
  @moduledoc """
  Time off for an employee: pending → approved / rejected, or cancelled.
  The employee's manager (or a workspace admin) decides; nobody approves
  their own. Working days (Mon–Fri) are counted and checked against the
  leave type's yearly allowance.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.HR,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.HR.LeaveRequest.Attributes,
      Zippiker.HR.LeaveRequest.Relationships,
      Zippiker.HR.LeaveRequest.Actions,
      Zippiker.HR.LeaveRequest.Policies
    ]

  postgres do
    table "leave_requests"
    repo Zippiker.Repo

    references do
      reference :employee, on_delete: :delete
      reference :leave_type, on_delete: :restrict
      reference :decided_by, on_delete: :nilify
    end

    custom_indexes do
      index [:employee_id, :start_date]
      index [:status]
    end
  end

  multitenancy do
    strategy :context
  end
end
