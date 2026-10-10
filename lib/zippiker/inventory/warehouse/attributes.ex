defmodule Zippiker.Inventory.Warehouse.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 120]

    attribute :code, :string do
      allow_nil? false
      public? true
      constraints max_length: 10, match: ~r/^[A-Za-z0-9-]+$/
    end

    attribute :address, :string, public?: true, constraints: [max_length: 500]
    attribute :default?, :boolean, allow_nil?: false, public?: true, default: false
    attribute :active?, :boolean, allow_nil?: false, public?: true, default: true

    timestamps()
  end
end
