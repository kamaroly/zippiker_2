defmodule Zippiker.HR.LeavePolicy.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 80]
    attribute :description, :string, public?: true, constraints: [max_length: 500]

    attribute :default?, :boolean do
      description "Applies to everyone without a policy of their own."
      allow_nil? false
      public? true
      default false
    end

    timestamps()
  end
end
