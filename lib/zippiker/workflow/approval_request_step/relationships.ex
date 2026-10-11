defmodule Zippiker.Workflow.ApprovalRequestStep.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :request, Zippiker.Workflow.ApprovalRequest, allow_nil?: false, public?: true

    belongs_to :user, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end

    belongs_to :group, Zippiker.Workflow.ApprovalGroup, public?: true

    belongs_to :decided_by, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end
  end
end
