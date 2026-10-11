defmodule Zippiker.HR.LeaveBalanceEntry.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :kind, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:accrual, :adjustment, :claim]
    end

    attribute :days, :decimal do
      description "Signed: positive adds to the balance, negative takes away."
      allow_nil? false
      public? true
    end

    attribute :effective_on, :date, allow_nil?: false, public?: true, default: &Date.utc_today/0

    attribute :period, :string do
      description "Accrual period key (e.g. `M2026-10`), so each period is credited once."
      public? true
      constraints max_length: 20
    end

    attribute :note, :string, public?: true, constraints: [max_length: 500]
    create_timestamp :inserted_at
  end
end
