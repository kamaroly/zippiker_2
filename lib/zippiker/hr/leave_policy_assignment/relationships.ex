defmodule Zippiker.HR.LeavePolicyAssignment.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :employee, Zippiker.HR.Employee, allow_nil?: false, public?: true
    belongs_to :leave_policy, Zippiker.HR.LeavePolicy, allow_nil?: false, public?: true

    belongs_to :leave_type, Zippiker.HR.LeaveType do
      description "Copied from the policy, so an employee has one policy per type."
      allow_nil? false
      public? true
    end
  end
end
