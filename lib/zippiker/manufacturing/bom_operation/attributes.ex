defmodule Zippiker.Manufacturing.BomOperation.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :position, :integer, allow_nil?: false, public?: true, default: 0
    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 120]

    attribute :minutes, :decimal do
      description "Time per batch (the bill of materials' quantity)."
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :instructions, :string, public?: true, constraints: [max_length: 2_000]
  end
end
