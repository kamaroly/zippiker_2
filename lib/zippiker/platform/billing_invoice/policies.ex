defmodule Zippiker.Platform.BillingInvoice.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  alias Zippiker.Accounts.Checks.ActorIsSuperAdmin

  policies do
    bypass ActorIsSuperAdmin do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(
                     exists(
                       organization.memberships,
                       user_id == ^actor(:id) and role in [:owner, :admin]
                     )
                   )
    end
  end
end
