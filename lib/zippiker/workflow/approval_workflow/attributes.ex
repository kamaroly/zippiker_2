defmodule Zippiker.Workflow.ApprovalWorkflow.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 80]

    attribute :document_type, :atom do
      allow_nil? false
      public? true
      default :expense_claim
      constraints one_of: Zippiker.Workflow.DocumentTypes.keys()
    end

    attribute :min_amount, :decimal do
      description "Applies to documents of at least this amount (0 = all)."
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :active?, :boolean, allow_nil?: false, public?: true, default: true
    timestamps()
  end
end
