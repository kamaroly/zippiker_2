defmodule Zippiker.HR.LeavePolicyRule.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      domain Zippiker.Accounts
    end

    belongs_to :leave_policy, Zippiker.HR.LeavePolicy, allow_nil?: false, public?: true
    belongs_to :leave_type, Zippiker.HR.LeaveType, allow_nil?: false, public?: true
  end
end
