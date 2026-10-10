defmodule Zippiker.Workflow.ApprovalWorkflow.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      domain Zippiker.Accounts
    end

    has_many :steps, Zippiker.Workflow.ApprovalStep do
      public? true
      destination_attribute :workflow_id
      sort position: :asc
    end
  end
end
