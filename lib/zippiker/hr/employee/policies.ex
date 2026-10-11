defmodule Zippiker.HR.Employee.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  alias Zippiker.Accounts.Checks.{ActorIsAdmin, ActorIsMember}

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

    # Self-service: people update their own contact details.
    policy action(:update_self) do
      authorize_if expr(not is_nil(user_id) and user_id == ^actor(:id))
    end

    policy action([:create, :update, :terminate, :rehire]) do
      authorize_if ActorIsAdmin
    end
  end

  # Pay and personal details: admins and the employee themselves.
  field_policies do
    field_policy [
      :salary,
      :pay_frequency,
      :date_of_birth,
      :national_id,
      :emergency_contact_name,
      :emergency_contact_phone
    ] do
      authorize_if ActorIsAdmin
      authorize_if expr(user_id == ^actor(:id))
    end

    field_policy :* do
      authorize_if always()
    end
  end
end
