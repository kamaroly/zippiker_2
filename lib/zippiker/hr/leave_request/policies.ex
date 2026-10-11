defmodule Zippiker.HR.LeaveRequest.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  alias Zippiker.Accounts.Checks.{ActorIsAdmin, ActorIsMember}
  alias Zippiker.HR.Checks.RequestsForThemselves

  policies do
    # Roles: plain members need the permission covering the action
    # (Zippiker.Accounts.Permissions).
    policy action_type([:create, :update, :destroy, :action]) do
      forbid_unless Zippiker.Accounts.Checks.Permitted
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if ActorIsMember
    end

    # Your own leave, or anyone's if you're an admin.
    policy action(:create) do
      authorize_if ActorIsAdmin
      authorize_if RequestsForThemselves
    end

    # The employee's manager or an admin, never the requester.
    policy action([:approve, :reject]) do
      forbid_if expr(not is_nil(employee.user_id) and employee.user_id == ^actor(:id))
      authorize_if ActorIsAdmin
      authorize_if expr(employee.manager.user_id == ^actor(:id))
      # Workflow requests: the engine checks the actor approves the current step.
      authorize_if expr(not is_nil(approval_request_id))
    end

    # Run by the overdue-review job with authorization off.
    policy action([:auto_decide, :link_approval, :mark_decided, :apply_approval]) do
      forbid_if always()
    end

    policy action(:cancel) do
      authorize_if ActorIsAdmin
      authorize_if expr(not is_nil(employee.user_id) and employee.user_id == ^actor(:id))
    end
  end
end
