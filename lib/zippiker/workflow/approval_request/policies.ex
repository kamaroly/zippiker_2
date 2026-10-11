defmodule Zippiker.Workflow.ApprovalRequest.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  # Who may decide is checked by the `ActorCanDecide` validation, because it
  # depends on the current step (manager, user, group or admins).
  policies do
    # Roles: plain members need the permission covering the action
    # (Zippiker.Accounts.Permissions).
    policy action_type([:create, :update, :destroy, :action]) do
      forbid_unless Zippiker.Accounts.Checks.Permitted
      authorize_if always()
    end

    policy always() do
      authorize_if Zippiker.Accounts.Checks.ActorIsMember
    end
  end
end
