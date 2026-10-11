defmodule Zippiker.HR.Employee.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :legal_entity, Zippiker.Accounts.LegalEntity do
      description "The employer."
      allow_nil? false
      public? true
      domain Zippiker.Accounts
    end

    # Always set (created from the name arguments when not given).
    belongs_to :party, Zippiker.Parties.Party do
      public? true
      domain Zippiker.Parties
    end

    belongs_to :user, Zippiker.Accounts.User do
      description "Their workspace login, if they have one."
      public? true
      domain Zippiker.Accounts
    end

    belongs_to :department, Zippiker.HR.Department, public?: true
    belongs_to :manager, Zippiker.HR.Employee, public?: true

    has_many :leave_policy_assignments, Zippiker.HR.LeavePolicyAssignment, public?: true

    many_to_many :leave_policies, Zippiker.HR.LeavePolicy do
      description "One per leave type; types without one use their default policy."
      public? true
      through Zippiker.HR.LeavePolicyAssignment
      source_attribute_on_join_resource :employee_id
      destination_attribute_on_join_resource :leave_policy_id
      join_relationship :leave_policy_assignments
    end

    has_many :direct_reports, Zippiker.HR.Employee do
      public? true
      destination_attribute :manager_id
      filter expr(status == :active)
    end

    has_many :leave_requests, Zippiker.HR.LeaveRequest, public?: true
  end
end
