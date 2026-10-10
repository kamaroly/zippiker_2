defmodule Zippiker.Crm.Deal.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :title, :string, allow_nil?: false, public?: true, constraints: [max_length: 160]

    attribute :amount, :money do
      description "Deal value, in the organization's base currency."
      public? true
    end

    attribute :status, :atom do
      description "Mirrors the stage kind so reporting never needs a join."
      allow_nil? false
      public? true
      default :open
      constraints one_of: [:open, :won, :lost]
    end

    attribute :expected_close_on, :date, public?: true
    attribute :closed_at, :utc_datetime_usec, public?: true
    attribute :lost_reason, :string, public?: true, constraints: [max_length: 255]
    attribute :description, :string, public?: true, constraints: [max_length: 5_000]

    attribute :position, :float do
      description "Sort order inside a board column; lower comes first."
      allow_nil? false
      public? true
      default 0.0
    end

    timestamps()
  end
end
