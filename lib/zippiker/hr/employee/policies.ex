defmodule Zippiker.HR.Employee.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  alias Zippiker.Accounts.Checks.{ActorIsAdmin, ActorIsMember}

  policies do
    policy action_type(:read) do
      authorize_if ActorIsMember
    end

    policy action_type([:create, :update]) do
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
