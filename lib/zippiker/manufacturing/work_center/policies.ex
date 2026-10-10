defmodule Zippiker.Manufacturing.WorkCenter.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  # Shared by work centers and bills of materials: everyone reads, admins set up.
  policies do
    policy action_type(:read) do
      authorize_if Zippiker.Accounts.Checks.ActorIsMember
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if Zippiker.Accounts.Checks.ActorIsAdmin
    end
  end
end
