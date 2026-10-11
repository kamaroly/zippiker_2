defmodule Zippiker.HR.ChecklistTask.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  alias Zippiker.Accounts.Checks.{ActorIsAdmin, ActorIsMember}

  policies do
    policy action_type(:read) do
      authorize_if ActorIsMember
    end

    # The assignee does their task; admins can do any (and HR tasks are theirs).
    policy action([:complete, :reopen]) do
      authorize_if ActorIsAdmin
      authorize_if expr(assignee_id == ^actor(:id))
    end

    policy action(:create) do
      forbid_if always()
    end
  end
end
