defmodule Zippiker.Accounting.JournalEntry.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :number, :string, public?: true
    attribute :date, :date, allow_nil?: false, public?: true, default: &Date.utc_today/0
    attribute :memo, :string, public?: true, constraints: [max_length: 500]

    attribute :source, :atom do
      description "Where the entry came from."
      allow_nil? false
      public? true
      default :manual

      constraints one_of: [
                    :manual,
                    :expense,
                    :invoice,
                    :payment,
                    :bill,
                    :bill_payment,
                    :stock,
                    :expense_claim,
                    :expense_reimbursement,
                    :production
                  ]
    end

    attribute :source_id, :uuid, public?: true
    attribute :source_label, :string, public?: true, constraints: [max_length: 60]

    attribute :total, :decimal do
      description "Sum of the debits (equal to the credits)."
      allow_nil? false
      public? true
      default 0
    end

    timestamps()
  end
end
