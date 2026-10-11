defmodule Zippiker.HR.LeaveBalanceEntry.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  alias Zippiker.Accounts.Checks.{ActorIsAdmin, ActorIsMember}

  policies do
    policy action_type(:read) do
      authorize_if ActorIsMember
    end

    policy action(:adjust) do
      authorize_if ActorIsAdmin
    end

    # Written by accruals and claim approvals with authorization off.
    policy action(:record) do
      forbid_if always()
    end
  end
end
