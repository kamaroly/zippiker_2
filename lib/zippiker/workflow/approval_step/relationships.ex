defmodule Zippiker.Workflow.ApprovalStep.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      domain Zippiker.Accounts
    end

    belongs_to :workflow, Zippiker.Workflow.ApprovalWorkflow, allow_nil?: false, public?: true

    belongs_to :user, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end

    belongs_to :group, Zippiker.Workflow.ApprovalGroup, public?: true
  end
end
