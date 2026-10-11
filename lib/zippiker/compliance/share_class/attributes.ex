defmodule Zippiker.Compliance.ShareClass.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 60]

    attribute :nominal_value, :decimal,
      allow_nil?: false,
      public?: true,
      default: 1,
      constraints: [min: 0]

    attribute :rights, :string, public?: true, constraints: [max_length: 1_000]
    timestamps()
  end
end
