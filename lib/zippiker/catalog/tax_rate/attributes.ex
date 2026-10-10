defmodule Zippiker.Catalog.TaxRate.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 60]

    attribute :rate, :decimal do
      description "Percentage, e.g. 18 for 18%."
      allow_nil? false
      public? true
      constraints min: 0, max: 100
    end

    attribute :default?, :boolean, allow_nil?: false, public?: true, default: false
    timestamps()
  end
end
