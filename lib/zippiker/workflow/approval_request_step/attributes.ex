defmodule Zippiker.Workflow.ApprovalRequestStep.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :position, :integer, allow_nil?: false, public?: true
    attribute :label, :string, public?: true, constraints: [max_length: 80]

    attribute :approver_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:manager, :user, :group, :admins]
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :waiting
      constraints one_of: [:waiting, :pending, :approved, :rejected, :skipped]
    end

    attribute :decided_at, :utc_datetime_usec, public?: true
    attribute :comment, :string, public?: true, constraints: [max_length: 1_000]
  end
end
