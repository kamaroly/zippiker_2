defmodule Zippiker.Workflow.ChangeRequest.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :legal_entity, Zippiker.Accounts.LegalEntity do
      allow_nil? false
      domain Zippiker.Accounts
    end

    belongs_to :requested_by, Zippiker.Accounts.User do
      description "The maker."
      public? true
      domain Zippiker.Accounts
    end

    belongs_to :approval_request, Zippiker.Workflow.ApprovalRequest, public?: true
  end
end
