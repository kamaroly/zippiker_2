defmodule Zippiker.Expenses.ExpenseClaim.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  alias Zippiker.Accounts.Checks.{ActorIsAdmin, ActorIsMember}

  policies do
    # Approvers need to see the claims they decide on, so members can read.
    policy action_type(:read) do
      authorize_if ActorIsMember
    end

    policy action(:create) do
      authorize_if ActorIsMember
    end

    policy action([:update, :submit, :cancel, :destroy]) do
      authorize_if expr(claimant_id == ^actor(:id))
      authorize_if ActorIsAdmin
    end

    # Paying people back is the finance side's job.
    policy action(:reimburse) do
      authorize_if ActorIsAdmin
    end

    # Driven by the approval workflow, which runs these without authorization.
    policy action([:set_total, :link_approval, :mark_approved, :mark_rejected, :apply_approval]) do
      forbid_if always()
    end
  end
end
