defmodule Zippiker.Manufacturing.BomComponent.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :position, :integer, allow_nil?: false, public?: true, default: 0

    attribute :quantity, :decimal do
      allow_nil? false
      public? true
      constraints greater_than: 0
    end
  end
end
