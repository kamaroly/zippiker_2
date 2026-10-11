defmodule Zippiker.HR.Holiday.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 80]
    attribute :date, :date, allow_nil?: false, public?: true

    attribute :recurring?, :boolean do
      description "Falls on the same month and day every year."
      allow_nil? false
      public? true
      default false
    end

    timestamps()
  end
end
