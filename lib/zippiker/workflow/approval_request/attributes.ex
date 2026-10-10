defmodule Zippiker.Workflow.ApprovalRequest.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :document_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:expense_claim]
    end

    attribute :document_id, :uuid, allow_nil?: false, public?: true
    attribute :document_label, :string, public?: true, constraints: [max_length: 120]
    attribute :amount, :decimal, allow_nil?: false, public?: true, default: 0

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :pending
      constraints one_of: [:pending, :approved, :rejected, :cancelled]
    end

    attribute :current_position, :integer, public?: true
    attribute :decided_at, :utc_datetime_usec, public?: true
    timestamps()
  end
end
