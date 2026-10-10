defmodule Zippiker.Accounting.JournalEntry.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Accounting.JournalEntry.Changes

  actions do
    defaults [:read]

    read :search do
      argument :query, :string

      argument :source, :atom,
        constraints: [
          one_of: [:manual, :expense, :invoice, :payment, :bill, :bill_payment, :stock]
        ]

      prepare Zippiker.Accounting.JournalEntry.Preparations.Search
      prepare build(sort: [date: :desc, number: :desc], load: [:reversal, :reversal_of])
      pagination offset?: true, countable: true, default_limit: 25, required?: false
    end

    create :create do
      description "A manual journal entry."
      primary? true
      accept [:date, :memo, :legal_entity_id]
      argument :lines, {:array, :map}, default: []

      change Changes.SetLegalEntity
      change relate_actor(:posted_by, allow_nil?: true)
      change Changes.PrepareLines
      change manage_relationship(:lines, type: :create)
      change Changes.AssignNumber
    end

    create :post do
      description "An automatic entry for a document from another module (idempotent per source)."
      accept [:date, :memo, :legal_entity_id, :source, :source_id, :source_label]
      argument :lines, {:array, :map}, default: []

      change Changes.SetLegalEntity
      change relate_actor(:posted_by, allow_nil?: true)
      change Changes.PrepareLines
      change manage_relationship(:lines, type: :create)
      change Changes.AssignNumber
    end

    create :reverse do
      description "Posts the mirror image of an entry (debits become credits)."
      argument :entry_id, :uuid, allow_nil?: false
      argument :date, :date
      argument :lines, {:array, :map}, default: []

      change Changes.Reverse
      change Changes.SetLegalEntity
      change relate_actor(:posted_by, allow_nil?: true)
      change Changes.PrepareLines
      change manage_relationship(:lines, type: :create)
      change Changes.AssignNumber
    end

    create :expense do
      description "Shortcut for a paid expense: debit the expense, credit cash or bank."
      accept [:date, :memo]
      argument :expense_account_id, :uuid, allow_nil?: false
      argument :paid_from_account_id, :uuid, allow_nil?: false
      argument :amount, :decimal, allow_nil?: false, constraints: [greater_than: 0]
      argument :party_id, :uuid
      argument :lines, {:array, :map}, default: []

      change Changes.BuildExpense
      change Changes.SetLegalEntity
      change relate_actor(:posted_by, allow_nil?: true)
      change Changes.PrepareLines
      change manage_relationship(:lines, type: :create)
      change Changes.AssignNumber
    end
  end
end
