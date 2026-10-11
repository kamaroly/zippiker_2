defmodule Zippiker.HR.EmployeeChecklist.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  alias Zippiker.Accounts.Checks.{ActorIsAdmin, ActorIsMember}

  policies do
    policy action_type(:read) do
      authorize_if ActorIsMember
    end

    policy action([:start, :cancel]) do
      authorize_if ActorIsAdmin
    end

    policy action(:refresh_status) do
      forbid_if always()
    end
  end
end
