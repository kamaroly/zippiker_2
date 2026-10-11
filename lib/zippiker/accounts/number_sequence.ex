defmodule Zippiker.Accounts.NumberSequence do
  @moduledoc """
  Gap-free document numbering per legal entity, document type and year,
  e.g. `INV-2026-0042`. Numbers are taken inside the caller's transaction with
  an atomic increment, so concurrent issuers never get the same number.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Accounts.NumberSequence.Attributes,
      Zippiker.Accounts.NumberSequence.Relationships,
      Zippiker.Accounts.NumberSequence.Actions,
      Zippiker.Accounts.NumberSequence.Policies
    ]

  postgres do
    table "number_sequences"
    repo Zippiker.Repo

    references do
      reference :legal_entity, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end

  identities do
    identity :unique_sequence, [:legal_entity_id, :document_type, :year]
  end
end
