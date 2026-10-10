defmodule Zippiker.Platform.Reports.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  policies do
    policy always() do
      authorize_if Zippiker.Accounts.Checks.ActorIsSuperAdmin
    end
  end
end
