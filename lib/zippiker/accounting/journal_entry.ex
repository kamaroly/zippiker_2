defmodule Zippiker.Accounting.JournalEntry do
  @moduledoc """
  A balanced set of debits and credits on one date. Entries are immutable:
  to undo one, post its reversal (`reverse`). Automatic entries remember the
  document they came from (`source` + `source_id`) so they are posted once.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Accounting,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Accounting.JournalEntry.Attributes,
      Zippiker.Accounting.JournalEntry.Relationships,
      Zippiker.Accounting.JournalEntry.Actions,
      Zippiker.Accounting.JournalEntry.Policies
    ]

  postgres do
    table "journal_entries"
    repo Zippiker.Repo

    identity_wheres_to_sql unique_number: "number IS NOT NULL",
                           unique_source: "source_id IS NOT NULL AND reversal_of_id IS NULL",
                           unique_reversal: "reversal_of_id IS NOT NULL"

    references do
      reference :legal_entity, on_delete: :restrict
      reference :posted_by, on_delete: :nilify
      reference :reversal_of, on_delete: :restrict
    end

    custom_indexes do
      index [:date]
    end
  end

  multitenancy do
    strategy :context
  end

  identities do
    identity :unique_number, [:legal_entity_id, :number], where: expr(not is_nil(number))

    identity :unique_source, [:source, :source_id],
      where: expr(not is_nil(source_id) and is_nil(reversal_of_id))

    identity :unique_reversal, [:reversal_of_id], where: expr(not is_nil(reversal_of_id))
  end
end
