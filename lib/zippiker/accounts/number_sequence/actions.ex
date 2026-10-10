defmodule Zippiker.Accounts.NumberSequence.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    create :open do
      accept [:legal_entity_id, :document_type, :year]
      upsert? true
      upsert_identity :unique_sequence
      upsert_fields []
    end

    update :increment do
      change atomic_update(:last_value, expr(last_value + 1))
    end

    action :next_number, :string do
      description "Allocates the next number, e.g. `INV-2026-0042`. Call inside the document's transaction."
      argument :legal_entity_id, :uuid, allow_nil?: false
      argument :document_type, :atom, allow_nil?: false
      argument :prefix, :string, allow_nil?: false
      argument :date, :date

      argument :yearly?, :boolean,
        default: true,
        description: "false = one running sequence (`EMP-0042`) instead of one per year"

      run Zippiker.Accounts.NumberSequence.Actions.NextNumber
    end
  end
end
