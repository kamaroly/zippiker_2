defmodule Zippiker.HR.ChecklistAttachment.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  alias Zippiker.Accounts.Checks.{ActorIsAdmin, ActorIsMember}

  policies do
    policy action_type(:read) do
      authorize_if ActorIsMember
    end

    policy action_type([:create, :destroy]) do
      authorize_if ActorIsAdmin
      authorize_if Zippiker.HR.Checks.AssigneeOfTask
    end
  end
end
