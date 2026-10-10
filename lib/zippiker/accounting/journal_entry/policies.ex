defmodule Zippiker.Accounting.JournalEntry.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  alias Zippiker.Accounts.Checks.{ActorIsAdmin, ActorIsMember}

  policies do
    policy action_type(:read) do
      authorize_if ActorIsMember
    end

    policy action(:expense) do
      authorize_if ActorIsMember
    end

    policy action([:create, :reverse, :post]) do
      authorize_if ActorIsAdmin
    end
  end
end
