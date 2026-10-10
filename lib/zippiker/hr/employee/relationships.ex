defmodule Zippiker.HR.Employee.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      domain Zippiker.Accounts
    end

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

    belongs_to :leave_policy, Zippiker.HR.LeavePolicy do
      description "Empty: the default policy applies."
      public? true
    end

    has_many :direct_reports, Zippiker.HR.Employee do
      public? true
      destination_attribute :manager_id
      filter expr(status == :active)
    end

    has_many :leave_requests, Zippiker.HR.LeaveRequest, public?: true
  end
end
