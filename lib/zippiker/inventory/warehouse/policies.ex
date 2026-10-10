defmodule Zippiker.Inventory.Warehouse.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  policies do
    policy action_type([:read, :action]) do
      authorize_if Zippiker.Accounts.Checks.ActorIsMember
    end

    policy action_type([:create, :update]) do
      authorize_if Zippiker.Accounts.Checks.ActorIsAdmin
    end
  end
end
