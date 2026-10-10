defmodule Zippiker.Sales.Reports.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  policies do
    policy always() do
      authorize_if Zippiker.Accounts.Checks.ActorIsMember
    end
  end
end
