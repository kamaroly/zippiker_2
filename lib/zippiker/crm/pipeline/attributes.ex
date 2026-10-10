defmodule Zippiker.Crm.Pipeline.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 80
    end

    attribute :position, :integer, allow_nil?: false, public?: true, default: 0

    timestamps()
  end
end
