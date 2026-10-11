defmodule Zippiker.HR.LeaveClaim.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :days, :decimal do
      allow_nil? false
      public? true
      constraints greater_than: 0
    end

    attribute :worked_on, :date do
      description "When the extra work happened."
      allow_nil? false
      public? true
    end

    attribute :reason, :string, allow_nil?: false, public?: true, constraints: [max_length: 1_000]

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :pending
      constraints one_of: [:pending, :approved, :rejected, :cancelled]
    end

    attribute :decided_at, :utc_datetime_usec, public?: true
    attribute :decision_note, :string, public?: true, constraints: [max_length: 500]
    timestamps()
  end
end
