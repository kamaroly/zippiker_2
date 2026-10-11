defmodule Zippiker.HR.LeaveClaim.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  alias Zippiker.Accounts.Checks.{ActorIsAdmin, ActorIsMember}
  alias Zippiker.HR.Checks.RequestsForThemselves

  policies do
    policy action_type(:read) do
      authorize_if ActorIsMember
    end

    policy action(:create) do
      authorize_if ActorIsAdmin
      authorize_if RequestsForThemselves
    end

    policy action([:approve, :reject]) do
      forbid_if expr(not is_nil(employee.user_id) and employee.user_id == ^actor(:id))
      authorize_if ActorIsAdmin
      authorize_if expr(employee.manager.user_id == ^actor(:id))
    end

    policy action(:cancel) do
      authorize_if ActorIsAdmin
      authorize_if expr(not is_nil(employee.user_id) and employee.user_id == ^actor(:id))
    end
  end
end
