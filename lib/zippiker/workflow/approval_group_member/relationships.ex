defmodule Zippiker.Workflow.ApprovalGroupMember.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :group, Zippiker.Workflow.ApprovalGroup, allow_nil?: false, public?: true

    belongs_to :user, Zippiker.Accounts.User do
      allow_nil? false
      public? true
      domain Zippiker.Accounts
    end
  end
end
