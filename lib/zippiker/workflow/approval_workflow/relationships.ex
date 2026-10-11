defmodule Zippiker.Workflow.ApprovalWorkflow.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    has_many :steps, Zippiker.Workflow.ApprovalStep do
      public? true
      destination_attribute :workflow_id
      sort position: :asc
    end
  end
end
