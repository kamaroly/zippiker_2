defmodule Zippiker.Workflow.ChangeRequest.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  alias Zippiker.Accounts.Checks.{ActorIsAdmin, ActorIsMember}

  policies do
    policy action_type(:read) do
      authorize_if ActorIsMember
    end

    policy action(:cancel) do
      authorize_if expr(requested_by_id == ^actor(:id))
      authorize_if ActorIsAdmin
    end

    # Created and resolved by the system (maker-checker hook and workflow).
    policy action([:request, :link_approval, :set_outcome, :apply_approval]) do
      forbid_if always()
    end
  end
end
