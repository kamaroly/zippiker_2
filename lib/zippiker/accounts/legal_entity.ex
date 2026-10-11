defmodule Zippiker.Accounts.LegalEntity do
  @moduledoc """
  A company inside a workspace that issues documents: its own legal name, tax
  id, address, currency, numbering prefixes and payment terms. Every workspace
  has a default one; groups with several companies add more.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Accounts.LegalEntity.Attributes,
      Zippiker.Accounts.LegalEntity.Relationships,
      Zippiker.Accounts.LegalEntity.Actions,
      Zippiker.Accounts.LegalEntity.Policies
    ]

  postgres do
    table "legal_entities"
    repo Zippiker.Repo

    identity_wheres_to_sql one_default: "\"default?\" = true"
  end

  multitenancy do
    strategy :context
  end

  identities do
    identity :one_default, [:default?], where: expr(default? == true)
  end
end
