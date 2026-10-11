defmodule Zippiker.Accounts.PortalAccess.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  alias Zippiker.Accounts.Checks.{ActorIsAdmin, ActorIsMember}

  policies do
    # The token holder looks their invitation up and claims it; everyone
    # sees their own portals.
    policy action([:by_token, :accept]) do
      authorize_if actor_present()
    end

    policy action(:mine) do
      authorize_if actor_present()
    end

    policy action(:for_party) do
      authorize_if ActorIsMember
    end

    policy action([:invite, :revoke, :read]) do
      authorize_if ActorIsAdmin
    end
  end
end
