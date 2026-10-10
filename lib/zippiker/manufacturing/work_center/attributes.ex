defmodule Zippiker.Manufacturing.WorkCenter.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 80]
    attribute :description, :string, public?: true, constraints: [max_length: 500]

    attribute :hourly_rate, :decimal do
      description "Labour and overhead per hour, in the workspace currency."
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :hours_per_day, :decimal do
      description "Available hours per working day (capacity)."
      allow_nil? false
      public? true
      default 8
      constraints min: 0, max: 24
    end

    attribute :active?, :boolean, allow_nil?: false, public?: true, default: true
    timestamps()
  end
end
