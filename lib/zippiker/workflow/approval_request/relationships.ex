defmodule Zippiker.Workflow.ApprovalRequest.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :workflow, Zippiker.Workflow.ApprovalWorkflow, public?: true

    belongs_to :requested_by, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end

    has_many :steps, Zippiker.Workflow.ApprovalRequestStep do
      public? true
      destination_attribute :request_id
      sort position: :asc
    end
  end
end
