defmodule Zippiker.Accounting.JournalLine do
  @moduledoc "One debit or credit of a journal entry. Carries the entry date for fast reporting."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Accounting,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Accounting.JournalLine.Attributes,
      Zippiker.Accounting.JournalLine.Relationships,
      Zippiker.Accounting.JournalLine.Actions,
      Zippiker.Accounting.JournalLine.Policies
    ]

  postgres do
    table "journal_lines"
    repo Zippiker.Repo

    references do
      reference :journal_entry, on_delete: :delete
      reference :account, on_delete: :restrict
      reference :party, on_delete: :nilify
    end

    custom_indexes do
      index [:account_id, :date]
    end
  end

  multitenancy do
    strategy :context
  end
end
