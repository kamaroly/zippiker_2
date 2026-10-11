defmodule Zippiker.HR.TimeActivity.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :date, :date, allow_nil?: false, public?: true

    attribute :hours, :decimal do
      allow_nil? false
      public? true
      constraints min: 0, max: 24
    end

    attribute :pay_type, :atom do
      description "How the hours are paid."
      allow_nil? false
      public? true
      default :regular
      constraints one_of: [:regular, :overtime, :weekend, :holiday, :sick, :vacation, :unpaid]
    end

    attribute :billable?, :boolean, allow_nil?: false, public?: true, default: false

    attribute :hourly_rate, :decimal do
      description "What the customer is charged per hour (billable time)."
      public? true
      constraints min: 0
    end

    attribute :description, :string, public?: true, constraints: [max_length: 500]
    timestamps()
  end
end
