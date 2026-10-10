defmodule Zippiker.Sales.Invoice.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  policies do
    policy action(:void) do
      authorize_if Zippiker.Accounts.Checks.ActorIsAdmin
    end

    policy always() do
      authorize_if Zippiker.Accounts.Checks.ActorIsMember
    end
  end
end
