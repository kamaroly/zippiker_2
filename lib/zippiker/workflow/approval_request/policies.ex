defmodule Zippiker.Workflow.ApprovalRequest.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  # Who may decide is checked by the `ActorCanDecide` validation, because it
  # depends on the current step (manager, user, group or admins).
  policies do
    policy always() do
      authorize_if Zippiker.Accounts.Checks.ActorIsMember
    end
  end
end
