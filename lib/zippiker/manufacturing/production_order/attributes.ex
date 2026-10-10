defmodule Zippiker.Manufacturing.ProductionOrder.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :number, :string, public?: true

    attribute :quantity, :decimal do
      description "How many units to make."
      allow_nil? false
      public? true
      constraints greater_than: 0
    end

    attribute :produced_quantity, :decimal, allow_nil?: false, public?: true, default: 0

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :draft
      constraints one_of: [:draft, :confirmed, :in_progress, :done, :cancelled]
    end

    attribute :planned_start, :date, public?: true, default: &Date.utc_today/0
    attribute :due_on, :date, public?: true
    attribute :notes, :string, public?: true, constraints: [max_length: 2_000]

    attribute :actual_cost, :decimal do
      description "Cost of everything produced so far (components + labour/overhead)."
      allow_nil? false
      public? true
      default 0
    end

    attribute :started_at, :utc_datetime_usec, public?: true
    attribute :finished_at, :utc_datetime_usec, public?: true
    timestamps()
  end

  calculations do
    calculate :remaining_quantity, :decimal, expr(quantity - produced_quantity), public?: true
  end
end
