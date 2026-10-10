defmodule Zippiker.Platform.AuditEvent.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  alias Zippiker.Accounts.Checks.ActorIsSuperAdmin

  policies do
    bypass ActorIsSuperAdmin do
      authorize_if always()
    end

    # Workspace admins (of the tenant) can ask for a plan change.
    policy action(:request_plan) do
      authorize_if Zippiker.Accounts.Checks.ActorIsAdmin
    end
  end
end
