defmodule Zippiker.Assistant.AiSettings do
  @moduledoc """
  The workspace's own AI provider: which provider and model, and its API
  key (encrypted, see `Zippiker.Assistant.Vault`; only the last four
  characters are ever shown). One row per workspace; without one the
  server's default (ANTHROPIC_API_KEY) is used.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Assistant,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Assistant.AiSettings.Attributes,
      Zippiker.Assistant.AiSettings.Actions,
      Zippiker.Assistant.AiSettings.Policies
    ]

  postgres do
    table "ai_settings"
    repo Zippiker.Repo
  end

  multitenancy do
    strategy :context
  end

  identities do
    identity :one_per_workspace, [:scope]
  end
end
