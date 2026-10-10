defmodule Zippiker.HR.LeavePolicy.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      domain Zippiker.Accounts
    end

    has_many :rules, Zippiker.HR.LeavePolicyRule, public?: true
    has_many :employees, Zippiker.HR.Employee, public?: true
  end
end
