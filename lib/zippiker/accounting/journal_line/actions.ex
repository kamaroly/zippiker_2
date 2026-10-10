defmodule Zippiker.Accounting.JournalLine.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    read :for_account do
      description "An account's postings, oldest first, for its ledger."
      argument :account_id, :uuid, allow_nil?: false
      argument :from, :date
      argument :to, :date

      filter expr(
               account_id == ^arg(:account_id) and
                 (is_nil(^arg(:from)) or date >= ^arg(:from)) and
                 (is_nil(^arg(:to)) or date <= ^arg(:to))
             )

      prepare build(
                sort: [date: :asc, inserted_at: :asc, position: :asc],
                load: [:journal_entry, :party]
              )
    end

    create :create do
      primary? true
      accept [:account_id, :party_id, :description, :debit, :credit, :position, :date]
      change Zippiker.Accounting.JournalLine.Changes.Defaults
    end
  end
end
