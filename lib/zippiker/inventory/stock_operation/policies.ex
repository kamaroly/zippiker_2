defmodule Zippiker.Inventory.StockOperation.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  alias Zippiker.Accounts.Checks.{ActorIsAdmin, ActorIsMember}

  policies do
    policy action_type(:read) do
      authorize_if ActorIsMember
    end

    policy action([:record, :adjust]) do
      authorize_if ActorIsMember
    end

    policy action(:reverse) do
      authorize_if ActorIsAdmin
    end
  end
end
