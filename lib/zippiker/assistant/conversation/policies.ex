defmodule Zippiker.Assistant.Conversation.Policies do
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  policies do
    policy always() do
      authorize_if Zippiker.Assistant.Checks.CanUseAssistant
    end
  end
end
