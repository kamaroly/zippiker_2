defmodule Zippiker.HR.LeavePolicy.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      domain Zippiker.Accounts
    end

    belongs_to :leave_type, Zippiker.HR.LeaveType, allow_nil?: false, public?: true

    has_many :assignments, Zippiker.HR.LeavePolicyAssignment, public?: true

    many_to_many :employees, Zippiker.HR.Employee do
      public? true
      through Zippiker.HR.LeavePolicyAssignment
      source_attribute_on_join_resource :leave_policy_id
      destination_attribute_on_join_resource :employee_id
      join_relationship :assignments
    end
  end
end
