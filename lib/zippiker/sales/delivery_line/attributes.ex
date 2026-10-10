defmodule Zippiker.Sales.DeliveryLine.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :position, :integer, allow_nil?: false, public?: true, default: 0

    attribute :description, :string,
      allow_nil?: false,
      public?: true,
      constraints: [max_length: 1_000]

    attribute :unit, :string, public?: true, constraints: [max_length: 20]
    attribute :quantity, :decimal, allow_nil?: false, public?: true, constraints: [min: 0]
  end
end
