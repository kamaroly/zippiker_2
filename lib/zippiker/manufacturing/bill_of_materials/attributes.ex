defmodule Zippiker.Manufacturing.BillOfMaterials.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :reference, :string do
      description "Name of this version, e.g. \"Standard\" or \"v2\"."
      allow_nil? false
      public? true
      default "Standard"
      constraints max_length: 60
    end

    attribute :quantity, :decimal do
      description "How many units of the product these components make."
      allow_nil? false
      public? true
      default 1
      constraints greater_than: 0
    end

    attribute :notes, :string, public?: true, constraints: [max_length: 2_000]
    attribute :active?, :boolean, allow_nil?: false, public?: true, default: true
    timestamps()
  end
end
