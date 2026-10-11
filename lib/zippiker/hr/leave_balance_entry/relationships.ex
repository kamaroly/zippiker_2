defmodule Zippiker.HR.LeaveBalanceEntry.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      domain Zippiker.Accounts
    end

    belongs_to :employee, Zippiker.HR.Employee, allow_nil?: false, public?: true
    belongs_to :leave_type, Zippiker.HR.LeaveType, allow_nil?: false, public?: true
    belongs_to :leave_policy, Zippiker.HR.LeavePolicy, public?: true
    belongs_to :claim, Zippiker.HR.LeaveClaim, public?: true

    belongs_to :created_by, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end
  end
end
