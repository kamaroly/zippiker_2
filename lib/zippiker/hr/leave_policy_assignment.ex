defmodule Zippiker.HR.LeavePolicyAssignment do
  @moduledoc "Puts an employee on a leave policy; at most one policy per leave type."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.HR,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.HR.LeavePolicyAssignment.Attributes,
      Zippiker.HR.LeavePolicyAssignment.Relationships,
      Zippiker.HR.LeavePolicyAssignment.Actions,
      Zippiker.HR.LeavePolicy.Policies
    ]

  postgres do
    table "leave_policy_assignments"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :employee, on_delete: :delete
      reference :leave_policy, on_delete: :delete
      reference :leave_type, on_delete: :delete
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  identities do
    identity :one_per_type, [:employee_id, :leave_type_id]
  end
end
