defmodule Zippiker.Expenses.ExpenseClaim.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      domain Zippiker.Accounts
    end

    belongs_to :legal_entity, Zippiker.Accounts.LegalEntity do
      allow_nil? false
      public? true
      domain Zippiker.Accounts
    end

    belongs_to :claimant, Zippiker.Accounts.User do
      description "Who is owed the money."
      allow_nil? false
      public? true
      domain Zippiker.Accounts
    end

    belongs_to :employee, Zippiker.HR.Employee do
      description "The claimant's employee record, when they have one."
      public? true
      domain Zippiker.HR
    end

    belongs_to :approval_request, Zippiker.Workflow.ApprovalRequest do
      description "The latest approval this claim went through."
      public? true
      domain Zippiker.Workflow
    end

    has_many :items, Zippiker.Expenses.ExpenseItem do
      public? true
      destination_attribute :claim_id
      sort position: :asc, spent_on: :asc
    end
  end
end
