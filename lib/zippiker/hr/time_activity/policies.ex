defmodule Zippiker.HR.TimeActivity.Policies do
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

    # Everyone logs their own time; admins log anyone's.
    policy action(:create) do
      authorize_if ActorIsAdmin
      authorize_if RequestsForThemselves
    end

    policy action([:update, :destroy]) do
      authorize_if ActorIsAdmin
      authorize_if expr(is_nil(invoice_id) and employee.user_id == ^actor(:id))
    end

    policy action(:mark_billed) do
      authorize_if ActorIsAdmin
    end
  end
end
