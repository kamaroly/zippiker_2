defmodule Zippiker.Workflow.ApprovalGroup.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 80]
    attribute :description, :string, public?: true, constraints: [max_length: 500]
    timestamps()
  end
end
